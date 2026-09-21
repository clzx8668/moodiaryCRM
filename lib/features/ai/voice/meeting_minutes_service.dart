import 'dart:convert';

import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/memory/memory_store.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

/// 会议/长语音的纪要结果。
class MeetingMinutesResult {
  const MeetingMinutesResult({
    required this.title,
    this.summary = '',
    this.decisions = const [],
    this.actions = const [],
    this.body = '',
  });

  final String title;
  final String summary;

  /// 已达成的决定/结论。
  final List<String> decisions;

  /// 后续行动（可含负责人与时间）。
  final List<String> actions;

  /// 结构化正文（Markdown：议题/讨论要点/风险与待确认）。
  final String body;

  bool get isEmpty =>
      summary.trim().isEmpty &&
      decisions.isEmpty &&
      actions.isEmpty &&
      body.trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'title': title,
    'summary': summary,
    'decisions': decisions,
    'actions': actions,
    'body': body,
  };

  /// 从模型输出解析（容错 ```json 围栏与纯文本）。
  static MeetingMinutesResult? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    var text = trimmed;
    final fence = RegExp(r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      json = null;
    }

    if (json == null) {
      // 非 JSON：按纯文本纪要兜底，不丢用户内容
      return MeetingMinutesResult(
        title: _fallbackTitle(text),
        body: text,
      );
    }

    final result = MeetingMinutesResult(
      title: _clean(json['title']?.toString() ?? ''),
      summary: json['summary']?.toString().trim() ?? '',
      decisions: _stringList(json['decisions']),
      actions: _stringList(json['actions']),
      body: (json['body'] ?? json['minutes'] ?? '').toString().trim(),
    );
    if (result.isEmpty) return null;
    return MeetingMinutesResult(
      title: result.title.isEmpty ? _fallbackTitle(result.summary) : result.title,
      summary: result.summary,
      decisions: result.decisions,
      actions: result.actions,
      body: result.body,
    );
  }

  /// 组装为落库的 Markdown（只渲染有内容的小节）。
  String toMarkdown() {
    final buffer = StringBuffer();
    if (summary.trim().isNotEmpty) {
      buffer
        ..writeln('## 摘要')
        ..writeln(summary.trim())
        ..writeln();
    }
    if (decisions.isNotEmpty) {
      buffer.writeln('## 决定');
      for (final item in decisions) {
        buffer.writeln('- $item');
      }
      buffer.writeln();
    }
    if (actions.isNotEmpty) {
      buffer.writeln('## 待办');
      for (final item in actions) {
        buffer.writeln('- [ ] $item');
      }
      buffer.writeln();
    }
    if (body.trim().isNotEmpty) {
      buffer
        ..writeln('## 纪要')
        ..writeln(_demoteHeadings(body.trim()));
    }
    return buffer.toString().trim();
  }

  /// 正文里的标题整体降一级，避免与「## 摘要/## 决定/## 待办/## 纪要」同级打架。
  static String _demoteHeadings(String markdown) {
    final lines = markdown.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final match = RegExp(r'^(#{1,5})\s+').firstMatch(lines[i]);
      if (match != null) {
        lines[i] = '#${lines[i]}';
      }
    }
    return lines.join('\n');
  }

  static String _clean(String value) => value.trim().replaceAll(
    RegExp(r'^[\s"“”]+|[\s"“”]+$'),
    '',
  );

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _fallbackTitle(String text) {
    final firstLine = text
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '会议纪要');
    final clean = firstLine.replaceAll(RegExp(r'^#+\s*'), '');
    return clean.length > 20 ? '${clean.substring(0, 20)}…' : clean;
  }
}

/// 纪要 Prompt（纯函数，便于单测与统一维护）。
class MeetingMinutesPrompts {
  MeetingMinutesPrompts._();

  static const String system =
      '你是会议记录整理助手，用中文输出。只输出 JSON，不要输出任何多余说明。';

  static const String instruction = '''
把下面的语音转写整理成结构化纪要：
1. 忠实原文，**不要编造**任何未出现的人名、数字、时间、金额；
2. 合并口语重复与无关寒暄，保留关键信息（谁、做什么、什么时间、什么条件）；
3. 若内容是单人备忘/闪念而非会议，则按「要点 + 待办」整理，同样不要编造；
4. 信息缺失就留空，不要用"待补充"等占位词填充。
返回 JSON：
{"title":"20 字以内标题","summary":"3-5 句摘要",
 "decisions":["已达成的决定"],"actions":["后续行动（含负责人/时间，如原话提到）"],
 "body":"Markdown 正文，按需分「议题 / 讨论要点 / 风险与待确认」小节"}
''';

  static String build(String transcript, {String profileSection = ''}) {
    final profile = profileSection.trim().isEmpty
        ? ''
        : '\n$profileSection\n';
    return '''
$system

$instruction
$profile
转写内容：
"""${transcript.trim()}"""
''';
  }
}

/// 会议纪要服务：长转写 → 结构化纪要（AI 派生，落 AI 生成区，原文不动）。
class MeetingMinutesService {
  MeetingMinutesService._();

  /// AI 块的模板标识（`BlockMeta.aiTemplate`）。
  static const String templateId = 'minutes';

  /// 生成纪要；失败返回 null（由调用方提示，不静默）。
  static Future<MeetingMinutesResult?> generate(
    String transcript, {
    String? title,
    AiProvider? provider,
  }) async {
    final text = transcript.trim();
    if (text.isEmpty) return null;

    final client = provider ?? await AiProviderFactory.loadLight();
    if (!client.isConfigured) return null;

    final completion = await client.completeChat([
      const AiChatMessage(role: 'system', content: MeetingMinutesPrompts.system),
      AiChatMessage(
        role: 'user',
        content: MeetingMinutesPrompts.build(
          text,
          profileSection: await MemoryStore.buildPromptSection(),
        ),
      ),
    ]);
    final parsed = MeetingMinutesResult.tryParse(completion.content);
    if (parsed == null) return null;
    // 用户已填标题时以用户标题为准（AI 标题仅作缺省）
    final preferred = title?.trim() ?? '';
    if (preferred.isEmpty) return parsed;
    return MeetingMinutesResult(
      title: preferred,
      summary: parsed.summary,
      decisions: parsed.decisions,
      actions: parsed.actions,
      body: parsed.body,
    );
  }

  /// 把纪要写入指定日记的 AI 生成区（新块，`source=ai`，原文保留）。
  static Future<Block?> saveAsAiBlock({
    required String diaryId,
    required MeetingMinutesResult minutes,
    String sourceContent = '',
  }) async {
    final markdown = minutes.toMarkdown();
    if (markdown.trim().isEmpty) return null;

    final blocks = await IsarUtil.getBlocksByDiary(diaryId);
    final sortOrder = blocks.isEmpty
        ? 0
        : blocks.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final now = DateTime.now();
    final block = Block()
      ..id = const Uuid().v7()
      ..diaryId = diaryId
      ..blockType = BlockType.text
      ..content = markdown
      ..sortOrder = sortOrder
      ..createdAt = now
      ..updatedAt = now
      ..meta = BlockMeta(
        source: BlockMeta.sourceAi,
        aiTemplate: templateId,
        sourceContent: sourceContent,
        title: minutes.title,
        captureType: 'meeting',
      );
    await IsarUtil.insertBlock(block);
    return block;
  }
}

