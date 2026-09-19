import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/voice/widgets/voice_player_card.dart';

void main() {
  group('播放进度 → 波形高亮柱数', () {
    test('开头为 0，结束为全部', () {
      expect(
        VoicePlayerCard.playedBars(
          barCount: 40,
          position: Duration.zero,
          total: const Duration(seconds: 10),
        ),
        0,
      );
      expect(
        VoicePlayerCard.playedBars(
          barCount: 40,
          position: const Duration(seconds: 10),
          total: const Duration(seconds: 10),
        ),
        40,
      );
    });

    test('按比例推进（播放中会"扫过"波形）', () {
      expect(
        VoicePlayerCard.playedBars(
          barCount: 40,
          position: const Duration(seconds: 5),
          total: const Duration(seconds: 10),
        ),
        20,
      );
      expect(
        VoicePlayerCard.playedBars(
          barCount: 100,
          position: const Duration(milliseconds: 2500),
          total: const Duration(seconds: 10),
        ),
        25,
      );
    });

    test('越界与异常输入被夹紧（不崩）', () {
      expect(
        VoicePlayerCard.playedBars(
          barCount: 10,
          position: const Duration(seconds: 30),
          total: const Duration(seconds: 10),
        ),
        10,
      );
      expect(
        VoicePlayerCard.playedBars(
          barCount: 10,
          position: const Duration(seconds: -5),
          total: const Duration(seconds: 10),
        ),
        0,
      );
      expect(
        VoicePlayerCard.playedBars(
          barCount: 0,
          position: Duration.zero,
          total: const Duration(seconds: 10),
        ),
        0,
      );
      // 时长未知（还没解析出来）：不高亮
      expect(
        VoicePlayerCard.playedBars(
          barCount: 10,
          position: const Duration(seconds: 1),
          total: Duration.zero,
        ),
        0,
      );
    });
  });
}
