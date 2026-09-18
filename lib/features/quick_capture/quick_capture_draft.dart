import 'dart:convert';

import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/persistence/pref.dart';

/// 快速收集面板的「临时记忆」：没写完就关掉，下次打开原样恢复。
///
/// 只在本地 Pref 存一份 JSON（文本 + 附件路径 + 已选模板），
/// 成功保存后清空；不写数据库、不影响笔记列表。
class QuickCaptureDraft {
  const QuickCaptureDraft({
    this.text = '',
    this.template = '',
    this.attachments = const [],
  });

  final String text;
  final String template;
  final List<QuickAttachment> attachments;

  bool get isEmpty =>
      text.trim().isEmpty && template.trim().isEmpty && attachments.isEmpty;

  Map<String, dynamic> toJson() => {
    'text': text,
    'template': template,
    'attachments': [
      for (final a in attachments)
        {'path': a.path, 'type': a.type.name, 'name': a.name},
    ],
  };

  static QuickCaptureDraft? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final attachments = <QuickAttachment>[];
    final list = raw['attachments'];
    if (list is List) {
      for (final item in list) {
        if (item is! Map) continue;
        final path = item['path']?.toString() ?? '';
        if (path.isEmpty) continue;
        final typeName = item['type']?.toString() ?? '';
        final rawName = (item['name']?.toString() ?? '').trim();
        attachments.add(
          QuickAttachment(
            path: path,
            type: QuickAttachmentType.values.firstWhere(
              (t) => t.name == typeName,
              orElse: () => QuickAttachmentType.other,
            ),
            name: rawName.isEmpty
                ? path.split(RegExp(r'[/\\]')).last
                : rawName,
          ),
        );
      }
    }
    return QuickCaptureDraft(
      text: raw['text']?.toString() ?? '',
      template: raw['template']?.toString() ?? '',
      attachments: attachments,
    );
  }
}

/// 草稿读写（PrefUtil 单键 JSON）。
class QuickCaptureDraftStore {
  QuickCaptureDraftStore._();

  static const String key = 'quickCaptureDraft';

  static QuickCaptureDraft load() {
    final raw = PrefUtil.getValue<String>(key) ?? '';
    if (raw.trim().isEmpty) return const QuickCaptureDraft();
    try {
      return QuickCaptureDraft.fromJson(jsonDecode(raw)) ??
          const QuickCaptureDraft();
    } catch (_) {
      return const QuickCaptureDraft();
    }
  }

  static Future<void> save(QuickCaptureDraft draft) async {
    if (draft.isEmpty) {
      await clear();
      return;
    }
    await PrefUtil.setValue<String>(key, jsonEncode(draft.toJson()));
  }

  static Future<void> clear() async {
    await PrefUtil.setValue<String>(key, '');
  }
}
