import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/voice/voice_level_envelope.dart';

void main() {
  group('录音响度包络', () {
    test('累计采样并按时长估算时长', () {
      final env = VoiceLevelEnvelope(sampleIntervalMs: 200);
      for (var i = 0; i < 10; i++) {
        env.add(0.5);
      }
      expect(env.length, 10);
      expect(env.duration, const Duration(seconds: 2));
    });

    test('脏数据（NaN/超界）被夹紧或清零', () {
      final env = VoiceLevelEnvelope();
      env.add(5);
      env.add(-2);
      env.add(double.nan);
      expect(env.raw, [1.0, 0.0, 0.0]);
    });

    test('降采样保留峰值形态（每桶取最大）', () {
      final env = VoiceLevelEnvelope();
      // 8 条 → 4 桶：每桶两个值，取大者
      for (final v in [0.1, 0.9, 0.2, 0.2, 0.8, 0.3, 0.0, 0.4]) {
        env.add(v);
      }
      expect(env.downsample(4), [0.9, 0.2, 0.8, 0.4]);
    });

    test('条数少于目标桶数：原样返回（渲染端自行补零）', () {
      final env = VoiceLevelEnvelope();
      env.add(0.3);
      env.add(0.6);
      expect(env.downsample(64), [0.3, 0.6]);
    });

    test('空包络降采样为空', () {
      expect(VoiceLevelEnvelope().downsample(64), isEmpty);
    });

    test('clear 清空', () {
      final env = VoiceLevelEnvelope()..add(0.5);
      env.clear();
      expect(env.length, 0);
      expect(env.downsample(8), isEmpty);
    });
  });

  group('存储解析容错（历史数据）', () {
    test('正常数组 → 0..1 的 double 列表', () {
      expect(VoiceLevelEnvelope.decode([0.2, 1, '0.75']), [0.2, 1.0, 0.75]);
    });

    test('非法项跳过、越界夹紧、超长截断', () {
      final decoded = VoiceLevelEnvelope.decode([
        0.5,
        'x',
        null,
        3.0,
        -1.0,
        ...List<double>.filled(300, 0.1),
      ], maxBuckets: 5);
      expect(decoded.first, 0.5);
      expect(decoded[1], 1.0); // 3.0 → 夹到 1
      expect(decoded[2], 0.0); // -1.0 → 夹到 0
      expect(decoded.length, 5); // 截断
    });

    test('缺失 / 类型不对 → 空列表（不抛异常）', () {
      expect(VoiceLevelEnvelope.decode(null), isEmpty);
      expect(VoiceLevelEnvelope.decode('not-a-list'), isEmpty);
      expect(VoiceLevelEnvelope.decode(const []), isEmpty);
    });
  });
}
