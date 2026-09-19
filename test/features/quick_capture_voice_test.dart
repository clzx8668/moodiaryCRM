import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/voice/voice_input_controller.dart';

void main() {
  // 批次 94 起：快速收集面板改成「点按麦克风 → 语音输入页（先录音、后决定）」，
  // 长按说话只剩详情页/AI 助手输入条在用，走向判定沿用同一实现。
  group('VoiceInputRoute.decide（长按说话走向，详情页/助手沿用）', () {
    test('配置了云端语音模型 → 录音落盘 + 云端转写', () {
      expect(
        VoiceInputRoute.decide(cloudReady: true, systemReady: true),
        VoiceInputRoute.cloud,
      );
      expect(
        VoiceInputRoute.decide(cloudReady: true, systemReady: false),
        VoiceInputRoute.cloud,
      );
    });

    test('未配云端但系统语音可用 → 本机实时听写（保持原行为）', () {
      expect(
        VoiceInputRoute.decide(cloudReady: false, systemReady: true),
        VoiceInputRoute.system,
      );
    });

    test('两者都不可用 → none（提示去配置，不静默失效）', () {
      expect(
        VoiceInputRoute.decide(cloudReady: false, systemReady: false),
        VoiceInputRoute.none,
      );
    });
  });

  group('appendVoiceText（转写文本追加回填）', () {
    test('空输入 → 直接填入', () {
      expect(appendVoiceText('', '明早九点开会'), '明早九点开会');
      expect(appendVoiceText('   ', ' 明早九点开会 '), '明早九点开会');
    });

    test('已有内容 → 追加到末尾并换行（长按语音可与已输入文字并存）', () {
      expect(appendVoiceText('先记一件事', '再补一句'), '先记一件事\n再补一句');
    });

    test('识别结果为空 → 保持原文', () {
      expect(appendVoiceText('原文', ''), '原文');
      expect(appendVoiceText('原文', '   '), '原文');
    });
  });
}
