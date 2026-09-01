import 'dart:convert';

import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';

import 'todo_item.dart';

/// Todo Block / Twenty task 快照 → 统一 [TodoItem] 的纯函数解析器。
///
/// 内容形态兼容两种：
/// - Markdown 任务行（`- [ ] 文本` / `- [x] 文本`，当前 App 与 AI todo 模板产物）；
/// - JSON（架构文档 3.2：`{"text": "...", "done": false, ...}` 或数组）。
class TodoParser {
  static final RegExp _taskLine = RegExp(r'^\s*[-*]\s+\[([ xX])\]\s+(.+)$');
  static final RegExp _checkbox = RegExp(r'\[([ xX])\]');

  /// 从 todo Block 提取任务条目；非任务行忽略。
  static List<TodoItem> fromBlock(Block block) {
    final trimmed = block.content.trim();
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return [
            for (var i = 0; i < decoded.length; i++)
              if (decoded[i] is Map) _fromJsonEntry(decoded[i], block, i),
          ];
        }
        if (decoded is Map) return [_fromJsonEntry(decoded, block, 0)];
      } catch (_) {
        // 非法 JSON 回退 Markdown 行解析
      }
    }

    final items = <TodoItem>[];
    final lines = block.content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final match = _taskLine.firstMatch(lines[i]);
      if (match == null) continue;
      items.add(
        TodoItem(
          id: '${block.id}:$i',
          source: TodoSource.localBlock,
          text: match.group(2)!.trim(),
          done: match.group(1)!.toLowerCase() == 'x',
          dueDate: _parseDate(block.meta.dueDate),
          time: block.updatedAt,
          diaryId: block.diaryId,
          blockId: block.id,
          lineIndex: i,
          title: '',
        ),
      );
    }
    return items;
  }

  /// Twenty task 缓存 → 待办条目；非 task 类型或已删除返回 null。
  static TodoItem? fromCrmTask(CrmEntityCache task) {
    if (task.entityType != 'task' || task.isDeleted) return null;
    final text = task.name.trim();
    if (text.isEmpty) return null;
    final data = task.data;
    final status = data['status']?.toString().toUpperCase() ?? '';
    final completed = data['completed'];
    final done = status == 'DONE' || completed == true;
    return TodoItem(
      id: task.twentyId.isEmpty ? task.id : task.twentyId,
      source: TodoSource.crmTask,
      text: text,
      done: done,
      dueDate: _parseDate(
        data['dueAt'] ?? data['dueDate'] ?? data['due_date'] ?? '',
      ),
      time: task.updatedAt,
      twentyId: task.twentyId,
      title: 'Twenty 任务',
    );
  }

  /// Schedule 实体 → 待办条目（批次 B）。
  static TodoItem fromSchedule(Schedule schedule) {
    return TodoItem(
      id: 'schedule:${schedule.id}',
      source: TodoSource.schedule,
      text: schedule.title,
      done: schedule.done,
      dueDate: schedule.floating ? null : schedule.startTime,
      time: schedule.updatedAt,
      scheduleId: schedule.id,
      isFloating: schedule.floating,
      priority: schedule.priority.value,
      title: schedule.repeatType == RepeatType.none
          ? '日程'
          : '日程 · ${schedule.repeatType.label}',
    );
  }

  static TodoItem _fromJsonEntry(
    dynamic raw,
    Block block,
    int index,
  ) {
    final map = raw as Map<String, dynamic>;
    final text = map['text']?.toString() ?? map['title']?.toString() ?? '';
    return TodoItem(
      id: '${block.id}:json:$index',
      source: TodoSource.localBlock,
      text: text.trim(),
      done: map['done'] == true,
      dueDate: _parseDate(map['dueDate'] ?? map['due_date'] ?? ''),
      time: block.updatedAt,
      diaryId: block.diaryId,
      blockId: block.id,
      lineIndex: index,
    );
  }

  /// 勾选时定位并改写 Block 内容中的任务行
  static String toggleLine(String content, int lineIndex, {required bool done}) {
    final lines = content.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) {
      throw RangeError('lineIndex $lineIndex 超出 Block 行数');
    }
    final line = lines[lineIndex];
    final match = _checkbox.firstMatch(line);
    if (match == null) {
      throw FormatException('第 $lineIndex 行不是任务行：$line');
    }
    lines[lineIndex] = line.replaceFirst(
      _checkbox,
      done ? '[x]' : '[ ]',
    );
    return lines.join('\n');
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }
}
