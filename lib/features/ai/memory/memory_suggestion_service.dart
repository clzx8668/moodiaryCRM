import 'package:flutter/foundation.dart';
import 'package:moodiary/features/ai/memory/memory_store.dart';
import 'package:moodiary/features/ai/memory/memory_suggestion.dart';
import 'package:moodiary/persistence/pref.dart';

/// 待确认的"值得记下来吗"——由 AI 任务结束时**本地生成**，等用户点确认才落盘。
///
/// 为什么用全局单例 + ValueNotifier：
/// 建议可能来自任意任务（AI 对话 / 技能 / 会议纪要），
/// 但用户只需要在一个地方看到它、点一下就落盘，所以统一挂在进程级。
class MemorySuggestionService {
  MemorySuggestionService._();

  static final MemorySuggestionService instance = MemorySuggestionService._();

  /// 开关（默认开；用户可在「记忆与画像」页关掉）
  static const String enabledPrefKey = 'memorySuggestionEnabled';

  /// 当前待处理的建议（null = 没有）。UI 用 ValueListenableBuilder 订阅它。
  final ValueNotifier<MemorySuggestion?> pending = ValueNotifier(null);

  /// 上次落盘的结果（用于 toast 文案）
  static bool get enabled {
    try {
      return PrefUtil.getValue<bool>(enabledPrefKey) ?? true;
    } catch (_) {
      // PrefUtil 未初始化（单测/极早期调用）：按默认开启处理
      return true;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      await PrefUtil.setValue(enabledPrefKey, value);
    } catch (e) {
      debugPrint('[MemorySuggestion] 保存开关失败：$e');
    }
  }

  /// 任务结束时调用：本地判断有没有值得记的东西，有就挂成待确认建议。
  ///
  /// **不落盘、不调模型**；已有待确认建议时不覆盖（避免刷屏）。
  void consider({required String aiOutput, String userAsk = ''}) {
    if (!enabled) return;
    if (pending.value != null) return;
    final s = MemorySuggestionDetector.detect(
      aiOutput: aiOutput,
      userAsk: userAsk,
    );
    if (s == null) return;
    pending.value = s;
  }

  /// 用户点「记住」：落盘（走 MemoryStore，自动打快照）。
  ///
  /// 返回给用户看的提示文案。
  Future<String> accept() async {
    final s = pending.value;
    pending.value = null;
    if (s == null) return '';
    switch (s.kind) {
      case MemorySuggestionKind.skill:
        await MemoryStore.saveSkill(s.title, s.content);
        return '已存为技能手册「${s.title}」';
      case MemorySuggestionKind.memory:
        await MemoryStore.appendMemory('**${s.title}**\n\n${s.content}');
        return '已记入长期记忆';
    }
  }

  /// 用户点「不用」/关闭：丢弃
  void dismiss() => pending.value = null;

  @visibleForTesting
  void reset() => pending.value = null;
}
