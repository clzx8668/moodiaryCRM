import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/voice/voice_level_wave.dart';

void main() {
  test('初始为静音（一条细线）', () {
    final wave = VoiceLevelWave(barCount: 8);
    expect(wave.samples.length, 8);
    expect(wave.peak, 0);
    expect(wave.smoothed, 0);
  });

  test('说话：电平推进成波形（平滑跟随，不尖刺）', () {
    final wave = VoiceLevelWave(barCount: 6, smoothing: 0.5);
    // 连续给满电平
    for (var i = 0; i < 10; i++) {
      wave.feed(1);
      wave.advance(active: true);
    }
    expect(wave.smoothed, greaterThan(0.9)); // 平滑但最终接近 1
    expect(wave.peak, greaterThan(0.9));
    // 波形是"滚动"的：最早一条已经被推走
    expect(wave.samples.first, lessThan(wave.samples.last));
  });

  test('停止录音后自然衰减回静音', () {
    final wave = VoiceLevelWave(barCount: 4, smoothing: 0.5);
    for (var i = 0; i < 8; i++) {
      wave.feed(1);
      wave.advance(active: true);
    }
    final loud = wave.peak;
    for (var i = 0; i < 30; i++) {
      wave.advance(active: false);
    }
    expect(wave.peak, lessThan(loud));
    expect(wave.smoothed, lessThan(0.05));
  });

  test('电平输入被夹在 0..1（脏数据不越界）', () {
    final wave = VoiceLevelWave(barCount: 4, smoothing: 0.0);
    wave.feed(5);
    wave.advance(active: true);
    expect(wave.smoothed, 1);
    wave.feed(-3);
    wave.advance(active: true);
    expect(wave.smoothed, 0);
  });

  test('reset 清空波形（重新录音）', () {
    final wave = VoiceLevelWave(barCount: 4, smoothing: 0.0);
    wave.feed(1);
    wave.advance(active: true);
    expect(wave.peak, 1);
    wave.reset();
    expect(wave.peak, 0);
    expect(wave.smoothed, 0);
  });
}
