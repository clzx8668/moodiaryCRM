import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/asr/wav_writer.dart';

Uint8List pcmBytes(int samples) {
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    data.setInt16(i * 2, 1000, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('wav_writer'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('写入头与数据，收尾回填真实长度', () async {
    final path = '${dir.path}/a.wav';
    final writer = WavWriter(path: path, sampleRate: 16000);
    await writer.open();
    await writer.add(pcmBytes(160)); // 320 字节 = 10ms
    await writer.add(pcmBytes(160));
    final total = await writer.close();

    expect(total, 640);
    final bytes = File(path).readAsBytesSync();
    expect(bytes.length, 44 + 640);
    // RIFF / WAVE / fmt / data 标记
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
    expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(4, Endian.little), 36 + 640); // RIFF size
    expect(data.getUint16(20, Endian.little), 1); // PCM
    expect(data.getUint16(22, Endian.little), 1); // mono
    expect(data.getUint32(24, Endian.little), 16000); // sample rate
    expect(data.getUint32(28, Endian.little), 32000); // byte rate
    expect(data.getUint16(32, Endian.little), 2); // block align
    expect(data.getUint16(34, Endian.little), 16); // bits
    expect(data.getUint32(40, Endian.little), 640); // data size
  });

  test('时长为 0 也合法（空录音）；重复 close 幂等', () async {
    final writer = WavWriter(path: '${dir.path}/b.wav');
    await writer.open();
    expect(await writer.close(), 0);
    expect(await writer.close(), 0);
    final bytes = File('${dir.path}/b.wav').readAsBytesSync();
    expect(bytes.length, 44);
  });

  test('duration 按字节数估算（16k/mono/16bit）', () async {
    final writer = WavWriter(path: '${dir.path}/c.wav');
    await writer.open();
    // 32000 字节 = 1 秒
    await writer.add(pcmBytes(16000));
    expect(writer.duration.inMilliseconds, 1000);
    await writer.close();
  });

  test('未 open 时 add 是安全空操作', () async {
    final writer = WavWriter(path: '${dir.path}/d.wav');
    await writer.add(pcmBytes(10));
    expect(writer.dataBytes, 0);
  });
}
