import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/asr/audio_leveler.dart';

Uint8List pcmOf(List<int> samples) {
  final d = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    d.setInt16(i * 2, samples[i], Endian.little);
  }
  return d.buffer.asUint8List();
}

double peakOf(Uint8List pcm) {
  final d = ByteData.sublistView(pcm);
  var p = 0;
  for (var i = 0; i < pcm.length ~/ 2; i++) {
    final v = d.getInt16(i * 2, Endian.little).abs();
    if (v > p) p = v;
  }
  return p / 32768.0;
}

void main() {
  group('AudioLeveler（录音电平自适应）', () {
    test('安静录音（16% 满量程）会被抬起来', () {
      final leveler = AudioLeveler();
      // 模拟真机实测：峰值约 0.16
      final quiet = pcmOf(List<int>.generate(512, (i) => i.isEven ? 5200 : -5200));
      var out = quiet;
      for (var i = 0; i < 40; i++) {
        out = leveler.process(quiet);
      }
      expect(peakOf(out), greaterThan(0.4), reason: '应被提升到 0.4 以上');
      expect(leveler.gain, greaterThan(2.0));
    });

    test('已经很响的录音不会被继续放大（增益下限 1.0）', () {
      final leveler = AudioLeveler();
      final loud = pcmOf(List<int>.generate(512, (i) => i.isEven ? 28000 : -28000));
      var out = loud;
      for (var i = 0; i < 20; i++) {
        out = leveler.process(loud);
      }
      expect(leveler.gain, lessThanOrEqualTo(1.05));
      expect(peakOf(out), lessThan(1.0), reason: '不能削顶溢出');
    });

    test('增益有上限，不会把底噪放大到刺耳', () {
      final leveler = AudioLeveler();
      final tiny = pcmOf(List<int>.generate(512, (i) => i.isEven ? 60 : -60));
      for (var i = 0; i < 100; i++) {
        leveler.process(tiny);
      }
      expect(leveler.gain, lessThanOrEqualTo(12.0));
    });

    test('绝不削顶：满量程输入输出仍在 int16 范围内', () {
      final leveler = AudioLeveler();
      final full = pcmOf(List<int>.filled(512, 32767));
      final out = leveler.process(full);
      final d = ByteData.sublistView(out);
      for (var i = 0; i < 512; i++) {
        final v = d.getInt16(i * 2, Endian.little);
        expect(v, lessThanOrEqualTo(32767));
        expect(v, greaterThanOrEqualTo(-32767));
      }
    });

    test('输出长度与输入一致（可原地替换到录音链路）', () {
      final leveler = AudioLeveler();
      final pcm = pcmOf(List<int>.generate(320, (i) => i * 10));
      expect(leveler.process(pcm).length, pcm.length);
    });

    test('reset 回到初始增益', () {
      final leveler = AudioLeveler();
      final quiet = pcmOf(List<int>.generate(512, (i) => i.isEven ? 3000 : -3000));
      for (var i = 0; i < 50; i++) {
        leveler.process(quiet);
      }
      expect(leveler.gain, greaterThan(1));
      leveler.reset();
      expect(leveler.gain, 1);
    });
  });
}
