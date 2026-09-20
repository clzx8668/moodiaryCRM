import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/asr/pcm_gate.dart';

Uint8List pcmOf(List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

Uint8List silence([int n = 320]) => pcmOf(List<int>.filled(n, 0));
Uint8List speech({int n = 320, int amp = 8000}) =>
    pcmOf(List<int>.generate(n, (i) => i.isEven ? amp : -amp));

void main() {
  group('PcmGate（能量门卫）', () {
    test('RMS：静音为 0，满幅接近 1', () {
      expect(PcmGate.rms(silence()), 0);
      final loud = PcmGate.rms(speech(amp: 32767));
      expect(loud, greaterThan(0.9));
    });

    test('短块/空块不崩', () {
      expect(PcmGate.rms(Uint8List(0)), 0);
      expect(PcmGate.rms(Uint8List(1)), 0);
    });

    test('静音不放行，说话放行', () {
      final gate = PcmGate();
      expect(gate.accept(silence()), isFalse);
      expect(gate.isSpeaking, isFalse);
      expect(gate.accept(speech()), isTrue);
      expect(gate.isSpeaking, isTrue);
    });

    test('挂起：句尾的短暂停顿仍放行，长时间静音后关闭', () {
      final gate = PcmGate(hangoverChunks: 3);
      gate.accept(speech());
      // 掉回静音后的 3 块仍然放行（保住句尾）
      expect(gate.accept(silence()), isTrue);
      expect(gate.accept(silence()), isTrue);
      expect(gate.accept(silence()), isTrue);
      // 第 4 块起不再放行
      expect(gate.accept(silence()), isFalse);
      expect(gate.isSpeaking, isFalse);
    });

    test('阈值可调：小声音在低阈值下也能触发', () {
      final strict = PcmGate(threshold: 0.4);
      final loose = PcmGate(threshold: 0.005);
      final quiet = speech(amp: 400); // ≈0.012 RMS
      expect(strict.accept(quiet), isFalse);
      expect(loose.accept(quiet), isTrue);
    });

    test('reset 清空状态', () {
      final gate = PcmGate()..accept(speech());
      gate.reset();
      expect(gate.isSpeaking, isFalse);
      expect(gate.accept(silence()), isFalse);
    });
  });

  group('AsrPartialText.merge（句子拼接）', () {
    test('空句忽略；首句直接落', () {
      expect(AsrPartialText.merge('', '你好'), '你好');
      expect(AsrPartialText.merge('你好', '   '), '你好');
    });

    test('依次追加：连接处自动补标点；重复句不重复追加', () {
      // 端侧模型不输出标点，merge 负责在连接处补上（短句用逗号）
      final both = AsrPartialText.merge('你好', '世界');
      expect(both.replaceAll(RegExp(r'[，。？！]'), ''), '你好世界');
      expect(RegExp(r'[，。？！]').hasMatch(both), isTrue);
      expect(AsrPartialText.merge('你好世界', '世界'), '你好世界');
    });
  });
}
