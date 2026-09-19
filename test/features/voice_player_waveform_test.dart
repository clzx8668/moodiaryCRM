import 'dart:math' as math;

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

  group('播放头跳动倍率（跟随该处真实响度）', () {
    test('静音处不跳', () {
      expect(VoicePlayerCard.pulseFactor(level: 0, phase: 1.2, offset: 0), 1.0);
      expect(
        VoicePlayerCard.pulseFactor(level: 0.01, phase: 0.4, offset: 1),
        1.0,
      );
    });

    test('有声处按响度摆动，且响度越大摆幅越大', () {
      final quiet = VoicePlayerCard.pulseFactor(
        level: 0.2,
        phase: math.pi / 2,
        offset: 0,
      );
      final loud = VoicePlayerCard.pulseFactor(
        level: 1.0,
        phase: math.pi / 2,
        offset: 0,
      );
      expect(quiet, greaterThan(1.0));
      expect(loud, greaterThan(quiet));
      // 摆动是有上下限的（不会把柱子甩出画布）
      expect(loud, lessThanOrEqualTo(1.5));
      expect(
        VoicePlayerCard.pulseFactor(level: 1, phase: -math.pi / 2, offset: 0),
        greaterThanOrEqualTo(0.5),
      );
    });

    test('不同柱子相位错开（看起来像流动而不是整体缩放）', () {
      final a = VoicePlayerCard.pulseFactor(level: 1, phase: 0.6, offset: 0);
      final b = VoicePlayerCard.pulseFactor(level: 1, phase: 0.6, offset: 2);
      expect(a, isNot(closeTo(b, 0.001)));
    });
  });
}
