import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moodiary/features/ai/memory/memory_files.dart';
import 'package:moodiary/features/ai/memory/memory_store.dart';

/// AI 上下文的**统一组装器**（批次 121）。
///
/// 解决的问题：以前每个入口各拼各的 system，结果
/// 「AI 页聊得像个懂你的人，笔记详情页却像失忆」。
/// 现在所有入口都从这里取上下文，保证：
///
/// 1. **全局**：画像 + 长期记忆（+ 命中关键词的技能手册）任何入口都注入**同一份**；
/// 2. **就地**：详情页交流额外带上「当前笔记正文」，并标明它是本次对话的对象；
/// 3. **有序**：全局 → 对象（笔记）→ 附加资料，越靠后注意力越强。
class PromptContext {
  PromptContext._();

  /// 通用助手人格（各入口可在此基础上追加）
  static const String defaultPersona = '你是用户的个人 AI 助手。回答使用 Markdown，简洁有条理。';

  /// 详情页交流的人格
  static const String notePersona =
      '你是用户的智能记录助手。请结合上下文，用简洁、结构化的 Markdown 回答。';

  /// 注入记忆后追加的一句提醒（防止模型把画像原文复述出来）
  static const String memoryGuidance = '（以上是关于用户的长期信息，回答时请自然遵守，不要复述。）';

  /// 笔记正文进上下文的上限：超长笔记只带头尾，避免挤爆上下文
  static const int noteContextLimit = 6000;

  /// 取全局分层记忆（画像 + 长期记忆 + 按关键词命中的技能手册）。
  ///
  /// 任何入口都应当调用它；失败时返回空串（**不能**因为记忆读不出来就中断对话）。
  static Future<String> loadMemorySection({String query = ''}) async {
    try {
      return await MemoryStore.buildPromptSection(query: query);
    } catch (e) {
      debugPrint('[PromptContext] 读取分层记忆失败：$e');
      return '';
    }
  }

  /// 组装"通用助手"的 system（AI 页 / 工具类任务用）。
  ///
  /// [persona] 默认 [defaultPersona]；[extraSections] 用来追加
  /// RAG 参考内容、联网搜索结果等**排在记忆之后**的内容。
  static String build({
    String? persona,
    required String memorySection,
    List<String> extraSections = const [],
  }) {
    final parts = <String>[persona ?? defaultPersona];
    if (memorySection.trim().isNotEmpty) {
      parts
        ..add(memorySection.trim())
        ..add(memoryGuidance);
    }
    for (final s in extraSections) {
      if (s.trim().isNotEmpty) parts.add(s.trim());
    }
    return parts.join('\n\n');
  }

  /// 组装"针对某条笔记"的 system（详情页 AI 交流用）。
  ///
  /// [noteText] 是当前笔记正文；[attachments] 是用户手动挂的附加资料。
  static String buildForNote({
    required String memorySection,
    required String noteText,
    List<String> attachments = const [],
    String? persona,
  }) {
    final parts = <String>[persona ?? notePersona];
    if (memorySection.trim().isNotEmpty) {
      parts
        ..add(memorySection.trim())
        ..add(memoryGuidance);
    }
    final note = noteText.trim();
    if (note.isNotEmpty) {
      parts.add(
        '# 当前笔记（本次对话的对象）\n'
        '用户正在看这条记录，问题基本都是围绕它展开的。\n'
        '"""\n$note\n"""',
      );
    }
    if (attachments.isNotEmpty) {
      final refs = [
        for (var i = 0; i < attachments.length; i++)
          '[资料 ${i + 1}]\n${attachments[i]}',
      ];
      parts.add('用户附加了以下参考资料，请优先参考：\n${refs.join('\n\n')}');
    }
    return parts.join('\n\n');
  }

  /// 截断过长的笔记正文（头一半 + 尾一半，中间标注省略字数）
  static String clipNoteText(String text) {
    if (text.length <= noteContextLimit) return text;
    final head = text.substring(0, noteContextLimit ~/ 2);
    final tail = text.substring(text.length - noteContextLimit ~/ 2);
    return '$head\n\n…（中间省略 ${text.length - noteContextLimit} 字）…\n\n$tail';
  }

  /// 从"已入库的笔记"读取正文（详情页用）。
  ///
  /// 取法：优先日记投影文本（列表/搜索看到的就是它），
  /// 再退回来源块拼接；**AI 卡片会被排除**，否则会把本轮对话自己塞回上下文。
  static String readNoteText({
    required String projection,
    required Iterable<({String content, bool isAi, bool isDeleted})> blocks,
  }) {
    final fromProjection = projection.trim();
    if (fromProjection.isNotEmpty) return clipNoteText(fromProjection);
    final buf = StringBuffer();
    for (final b in blocks) {
      if (b.isDeleted || b.isAi) continue;
      final c = b.content.trim();
      if (c.isEmpty) continue;
      buf.writeln(c);
    }
    return clipNoteText(buf.toString().trim());
  }

  /// 当前记忆文件目录（设置页/诊断用）
  static String memoryDir() => MemoryFiles.rootDir();

  /// 记忆目录是否存在（用于"是否需要提示用户去建"）
  static bool memoryDirExists() => Directory(MemoryFiles.rootDir()).existsSync();
}
