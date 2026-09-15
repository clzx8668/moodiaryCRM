import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/voice/wav_splitter.dart';

/// 造一段 PCM16 音频（[silentRanges] 为按样本计数的静音区间）。
List<int> _pcm16(
  int samples, {
  int amplitude = 8000,
  List<List<int>> silentRanges = const [],
}) {
  final out = List<int>.filled(samples, amplitude);
  for (final range in silentRanges) {
    for (var i = range[0]; i < range[1] && i < samples; i++) {
      out[i] = 0;
    }
  }
  return out;
}

List<int> _wav(
  List<int> samples, {
  int sampleRate = 8000,
  int channels = 1,
}) {
  final payload = <int>[];
  for (final sample in samples) {
    for (var c = 0; c < channels; c++) {
      payload
        ..add(sample & 0xFF)
        ..add((sample >> 8) & 0xFF);
    }
  }
  return WavSplitter.buildWav(
    payload,
    WavFormat(
      audioFormat: 1,
      channels: channels,
      sampleRate: sampleRate,
      bitsPerSample: 16,
      dataOffset: 0,
      dataSize: 0,
    ),
  );
}

void main() {
  group('WavSplitter.parse', () {
    test('解析 PCM16 单声道头与数据区', () {
      final bytes = _wav(_pcm16(8000));
      final format = WavSplitter.parse(bytes)!;
      expect(format.audioFormat, 1);
      expect(format.channels, 1);
      expect(format.sampleRate, 8000);
      expect(format.bitsPerSample, 16);
      expect(format.bytesPerFrame, 2);
      expect(format.dataOffset, 44);
      expect(format.dataSize, 16000);
      expect(format.duration, const Duration(seconds: 1));
      expect(format.isPcm16, isTrue);
    });

    test('立体声按 4 字节一帧，时长正确', () {
      final bytes = _wav(_pcm16(8000), sampleRate: 16000, channels: 2);
      final format = WavSplitter.parse(bytes)!;
      expect(format.bytesPerFrame, 4);
      expect(format.duration, const Duration(milliseconds: 500));
    });

    test('非 WAV / 截断 / 压缩格式 → null', () {
      expect(WavSplitter.parse(List<int>.filled(100, 1)), isNull);
      expect(WavSplitter.parse(_wav(_pcm16(10)).sublist(0, 20)), isNull);
      final compressed = _wav(_pcm16(10));
      compressed[20] = 7; // fmt 的 audioFormat 改成 µ-law
      compressed[21] = 0;
      expect(WavSplitter.parse(compressed), isNull);
    });

    test('data 之前的额外块（LIST）不影响定位', () {
      final base = _wav(_pcm16(100));
      final fmt = base.sublist(12, 36);
      final data = base.sublist(36);
      final list = <int>[
        ...'LIST'.codeUnits,
        4, 0, 0, 0, 1, 2, 3, 4,
      ];
      final rebuilt = <int>[
        ...'RIFF'.codeUnits,
        0, 0, 0, 0,
        ...'WAVE'.codeUnits,
        ...fmt,
        ...list,
        ...data,
      ];
      final format = WavSplitter.parse(rebuilt)!;
      expect(format.dataSize, 200);
      expect(format.dataOffset, 36 + list.length + 8);
    });
  });

  group('WavSplitter.plan', () {
    test('按目标字节切片并对齐到帧，覆盖全部数据', () {
      final samples = _pcm16(8000 * 10); // 10 秒
      final bytes = _wav(samples);
      final format = WavSplitter.parse(bytes)!;
      final chunks = WavSplitter.plan(
        format,
        maxBytesPerChunk: 16000, // 每片 1 秒
        pcm: bytes,
      );

      expect(chunks.length, 10);
      expect(chunks.first.startByte, format.dataOffset);
      expect(chunks.last.endByte, format.dataOffset + format.dataSize);
      for (final chunk in chunks) {
        expect(chunk.byteLength % format.bytesPerFrame, 0);
        expect(chunk.byteLength, lessThanOrEqualTo(16000));
        expect(chunk.duration, const Duration(seconds: 1));
      }
      for (var i = 1; i < chunks.length; i++) {
        expect(chunks[i].startByte, chunks[i - 1].endByte);
      }
    });

    test('目标小于一帧 → 不切片（交给单发）', () {
      final bytes = _wav(_pcm16(100));
      final format = WavSplitter.parse(bytes)!;
      expect(WavSplitter.plan(format, maxBytesPerChunk: 1, pcm: bytes), isEmpty);
    });

    test('帧对齐回归：目标半片为奇数时也必须对齐（否则切片变噪声）', () {
      // maxBytesPerChunk=16002 → targetBytes=16002（偶数），但半分 8001 为奇数；
      // 早期实现把静音候选点放在奇数字节上，切出的 WAV 整体错位一字节 →
      // 音频变成全幅噪声，ASR 直接产生幻觉文本（批次 70 实机联调踩坑）。
      final samples = _pcm16(
        8000 * 10,
        silentRanges: [
          [8000 * 4, 8000 * 5],
        ],
      );
      final bytes = _wav(samples);
      final format = WavSplitter.parse(bytes)!;
      final chunks = WavSplitter.plan(
        format,
        maxBytesPerChunk: 16002,
        pcm: bytes,
      );

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(
          (chunk.startByte - format.dataOffset) % format.bytesPerFrame,
          0,
          reason: 'startByte=${chunk.startByte}',
        );
        expect(chunk.byteLength % format.bytesPerFrame, 0);
      }

      // 每片解出的 WAV 数据区应逐字节等于原文件对应区间（错位即失败）
      for (final chunk in chunks) {
        final extracted = WavSplitter.extract(bytes, format, chunk);
        final extractedFormat = WavSplitter.parse(extracted)!;
        expect(
          extracted.sublist(extractedFormat.dataOffset),
          bytes.sublist(chunk.startByte, chunk.endByte),
        );
      }
    });

    test('立体声（4 字节一帧）切片同样对齐', () {
      final samples = _pcm16(
        16000 * 4,
        silentRanges: [
          [16000 * 2, 16000 * 3],
        ],
      );
      final bytes = _wav(samples, sampleRate: 16000, channels: 2);
      final format = WavSplitter.parse(bytes)!;
      final chunks = WavSplitter.plan(
        format,
        maxBytesPerChunk: 64006,
        pcm: bytes,
      );
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(
          (chunk.startByte - format.dataOffset) % format.bytesPerFrame,
          0,
        );
        expect(chunk.byteLength % format.bytesPerFrame, 0);
      }
    });

    test('切点优先落在静音处，避免句中被截断', () {
      // 10 秒：4.5s–5.5s 为静音；目标切点在 5.0s（静音正中）
      final samples = _pcm16(
        8000 * 10,
        silentRanges: [
          [8000 * 9 ~/ 2, 8000 * 11 ~/ 2],
        ],
      );
      final bytes = _wav(samples);
      final format = WavSplitter.parse(bytes)!;
      final chunks = WavSplitter.plan(
        format,
        maxBytesPerChunk: 8000 * 2 * 5, // 5 秒
        pcm: bytes,
      );

      expect(chunks.length, 2);
      final cutPayload = chunks.first.endByte - format.dataOffset;
      // 静音区间（按字节）：72000–88000
      expect(cutPayload, greaterThanOrEqualTo(72000));
      expect(cutPayload, lessThanOrEqualTo(88000));
    });
  });

  group('WavSplitter.extract', () {
    test('切片写出后仍是合法 WAV，且数据与原文逐字节一致', () {
      final samples = _pcm16(8000 * 3);
      final bytes = _wav(samples);
      final format = WavSplitter.parse(bytes)!;
      final chunks = WavSplitter.plan(
        format,
        maxBytesPerChunk: 16000,
        pcm: bytes,
      );

      final payloads = <int>[];
      for (final chunk in chunks) {
        final chunkBytes = WavSplitter.extract(bytes, format, chunk);
        final chunkFormat = WavSplitter.parse(chunkBytes)!;
        expect(chunkFormat.sampleRate, format.sampleRate);
        expect(chunkFormat.channels, format.channels);
        expect(chunkFormat.bitsPerSample, format.bitsPerSample);
        expect(chunkFormat.dataSize, chunk.byteLength);
        payloads.addAll(
          chunkBytes.sublist(chunkFormat.dataOffset),
        );
      }
      expect(payloads, bytes.sublist(format.dataOffset));
    });
  });
}
