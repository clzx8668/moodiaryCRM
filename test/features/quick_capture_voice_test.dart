import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/quick_capture/quick_capture_logic.dart';

void main() {
  group('QuickCaptureVoiceRoute.decide（长按说话走向）', () {
    test('配置了云端语音模型 → 录音落盘 + 云端转写', () {
      expect(
        QuickCaptureVoiceRoute.decide(cloudReady: true, systemReady: true),
        QuickCaptureVoiceRoute.cloud,
      );
      expect(
        QuickCaptureVoiceRoute.decide(cloudReady: true, systemReady: false),
        QuickCaptureVoiceRoute.cloud,
      );
    });

    test('未配云端但系统语音可用 → 本机实时听写（保持原行为）', () {
      expect(
        QuickCaptureVoiceRoute.decide(cloudReady: false, systemReady: true),
        QuickCaptureVoiceRoute.system,
      );
    });

    test('两者都不可用 → none（提示去配置，不静默失效）', () {
      expect(
        QuickCaptureVoiceRoute.decide(cloudReady: false, systemReady: false),
        QuickCaptureVoiceRoute.none,
      );
    });
  });

  group('QuickCaptureLogic.appendTranscript（语音回填）', () {
    test('空输入 → 直接填入', () {
      expect(QuickCaptureLogic.appendTranscript('', '明早九点开会'), '明早九点开会');
      expect(
        QuickCaptureLogic.appendTranscript('   ', ' 明早九点开会 '),
        '明早九点开会',
      );
    });

    test('已有内容 → 追加到末尾并换行（长按语音可与已输入文字并存）', () {
      expect(
        QuickCaptureLogic.appendTranscript('先记一件事', '再补一句'),
        '先记一件事\n再补一句',
      );
    });

    test('识别结果为空 → 保持原文', () {
      expect(QuickCaptureLogic.appendTranscript('原文', ''), '原文');
      expect(QuickCaptureLogic.appendTranscript('原文', '   '), '原文');
    });
  });
}
