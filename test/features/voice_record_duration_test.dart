import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/voice/voice_record_page.dart';

void main() {
  group('VoiceRecordPage.formatRecordDuration', () {
    test('零时长', () {
      expect(VoiceRecordPage.formatRecordDuration(Duration.zero), '00:00');
    });
    test('补零', () {
      expect(
        VoiceRecordPage.formatRecordDuration(const Duration(seconds: 65)),
        '01:05',
      );
      expect(
        VoiceRecordPage.formatRecordDuration(const Duration(minutes: 12)),
        '12:00',
      );
    });
    test('超过一小时按分钟取余显示', () {
      expect(
        VoiceRecordPage.formatRecordDuration(const Duration(seconds: 3661)),
        '01:01',
      );
    });
  });
}
