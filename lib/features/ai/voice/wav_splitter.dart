import 'dart:typed_data';

/// WAV 头信息（RIFF/WAVE 解析结果）。
class WavFormat {
  const WavFormat({
    required this.audioFormat,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataSize,
  });

  /// 1 = PCM，3 = IEEE float，0xFFFE = extensible（按 fmt 里的位深处理）。
  final int audioFormat;
  final int channels;
  final int sampleRate;
  final int bitsPerSample;

  /// 音频数据起始偏移与字节数（不含头部）。
  final int dataOffset;
  final int dataSize;

  int get bytesPerFrame => channels * (bitsPerSample ~/ 8);

  bool get isPcm16 => audioFormat == 1 && bitsPerSample == 16;

  bool get isSplittable => bytesPerFrame > 0 && dataSize > 0;

  Duration get duration {
    if (!isSplittable || sampleRate <= 0) return Duration.zero;
    return Duration(
      microseconds: dataSize * 1000000 ~/ (bytesPerFrame * sampleRate),
    );
  }
}

/// 一个切片在原文件中的字节范围与对应时间范围。
class WavChunk {
  const WavChunk({
    required this.startByte,
    required this.endByte,
    required this.start,
    required this.end,
  });

  final int startByte;
  final int endByte;
  final Duration start;
  final Duration end;

  int get byteLength => endByte - startByte;

  Duration get duration => end - start;
}

/// WAV 切片（纯函数，零依赖）。
///
/// 用途：把长录音切成若干「Base64 后仍在接口体积限制内」的小段，逐段转写后合并，
/// 从而摆脱「单文件 8MB ≈ 1.5 分钟」的硬限制。
///
/// 切点策略：优先落在**静音处**（PCM16 时按 20ms 帧做能量最小点搜索），
/// 避免一句话被切两半造成边界丢字；找不到合适静音则按目标字节切（帧对齐）。
class WavSplitter {
  WavSplitter._();

  /// 能量计算帧长。
  static const Duration analysisFrame = Duration(milliseconds: 20);

  /// 解析 RIFF/WAVE；不是规范的 WAV（或有压缩）时返回 null，由调用方退回单发。
  static WavFormat? parse(List<int> bytes) {
    if (bytes.length < 44) return null;
    if (!_tagEquals(bytes, 0, 'RIFF') || !_tagEquals(bytes, 8, 'WAVE')) {
      return null;
    }

    int? audioFormat;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? dataOffset;
    int? dataSize;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = _tagAt(bytes, offset);
      final size = _u32(bytes, offset + 4);
      final body = offset + 8;
      if (size < 0) return null;

      if (id == 'fmt ') {
        if (body + 16 > bytes.length) return null;
        audioFormat = _u16(bytes, body);
        channels = _u16(bytes, body + 2);
        sampleRate = _u32(bytes, body + 4);
        bitsPerSample = _u16(bytes, body + 14);
      } else if (id == 'data') {
        dataOffset = body;
        dataSize = size.clamp(0, bytes.length - body);
      }

      offset = body + size + (size.isOdd ? 1 : 0);
    }

    if (audioFormat == null ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample == null ||
        dataOffset == null ||
        dataSize == null ||
        channels <= 0 ||
        sampleRate <= 0 ||
        bitsPerSample <= 0) {
      return null;
    }
    // 只支持无损 PCM / IEEE float（1 / 3）与 extensible（0xFFFE）容器
    if (audioFormat != 1 && audioFormat != 3 && audioFormat != 0xFFFE) {
      return null;
    }

    return WavFormat(
      audioFormat: audioFormat,
      channels: channels,
      sampleRate: sampleRate,
      bitsPerSample: bitsPerSample,
      dataOffset: dataOffset,
      dataSize: dataSize,
    );
  }

  /// 规划切片：每片数据不超过 [maxBytesPerChunk]（按帧对齐）。
  ///
  /// [pcm] 传入完整文件字节时启用静音优先切点（仅 PCM16 生效）。
  static List<WavChunk> plan(
    WavFormat format, {
    required int maxBytesPerChunk,
    List<int>? pcm,
  }) {
    if (!format.isSplittable) return const [];
    final frame = format.bytesPerFrame;
    final targetBytes = (maxBytesPerChunk ~/ frame) * frame;
    if (targetBytes < frame) return const [];

    final dataEnd = format.dataOffset + format.dataSize;
    final chunks = <WavChunk>[];
    var start = format.dataOffset;
    var guard = 0;
    while (start < dataEnd && guard++ < 100000) {
      var end = start + targetBytes;
      if (end >= dataEnd) end = dataEnd;
      if (end < dataEnd && pcm != null && format.isPcm16) {
        // 在「半片 ~ 1.5 片」范围内找静音切点，避免切出碎片
        // 注意：所有候选位置必须先对齐到采样帧，否则切出的 WAV 会整体错位一个字节，
        // 变成全幅噪声（ASR 会直接产生幻觉文本）——这是批次 70 实机联调踩到的坑。
        final lower = _floorToFrame(format, start + targetBytes ~/ 2);
        final upper = _floorToFrame(format, start + targetBytes * 3 ~/ 2);
        final cut = _quietestCut(
          format,
          pcm,
          target: end,
          lower: lower,
          upper: upper > dataEnd ? dataEnd : upper,
        );
        if (cut != null) end = cut;
      }
      if (end <= start) end = dataEnd < start + frame ? dataEnd : start + frame;
      chunks.add(
        WavChunk(
          startByte: start,
          endByte: end,
          start: _timeAt(format, start),
          end: _timeAt(format, end),
        ),
      );
      start = end;
    }
    return chunks;
  }

  /// 抽出某个切片并写成独立的标准 WAV（44 字节头 + 数据）。
  static List<int> extract(List<int> source, WavFormat format, WavChunk chunk) {
    final end = chunk.endByte.clamp(0, source.length);
    final start = chunk.startByte.clamp(0, end);
    return buildWav(source.sublist(start, end), format);
  }

  /// 用给定音频数据构造标准 WAV 字节。
  static List<int> buildWav(List<int> payload, WavFormat format) {
    final header = BytesBuilder();
    void ascii(String value) => header.add(value.codeUnits);
    void u16(int value) =>
        header.add([value & 0xFF, (value >> 8) & 0xFF]);
    void u32(int value) => header.add([
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ]);

    final byteRate = format.sampleRate * format.bytesPerFrame;
    ascii('RIFF');
    u32(36 + payload.length);
    ascii('WAVE');
    ascii('fmt ');
    u32(16);
    u16(format.audioFormat == 0xFFFE ? 1 : format.audioFormat);
    u16(format.channels);
    u32(format.sampleRate);
    u32(byteRate);
    u16(format.bytesPerFrame);
    u16(format.bitsPerSample);
    ascii('data');
    u32(payload.length);
    header.add(payload);
    return header.toBytes();
  }

  /// 在 `[lower, upper]` 内找能量最小的 20ms 帧起点（帧对齐）；
  /// 能量相同时取最接近 [target] 的位置。
  static int? _quietestCut(
    WavFormat format,
    List<int> pcm, {
    required int target,
    required int lower,
    required int upper,
  }) {
    final frameBytes = format.bytesPerFrame;
    final analysisBytes =
        frameBytes * (format.sampleRate * analysisFrame.inMilliseconds ~/ 1000);
    if (analysisBytes <= 0) return null;
    final from = _floorToFrame(format, lower);
    final to = _floorToFrame(format, upper);
    if (to <= from) return null;

    // 候选步长取 50ms（帧对齐）
    var candidateStride = frameBytes * (format.sampleRate ~/ 20);
    if (candidateStride < frameBytes) candidateStride = frameBytes;
    var bestStart = -1;
    var bestEnergy = -1;
    var bestDistance = 1 << 62;
    for (var pos = from; pos <= to; pos += candidateStride) {
      final energy = _energy(pcm, pos, analysisBytes, frameBytes);
      if (energy < 0) return null;
      final distance = (pos - target).abs();
      if (bestEnergy < 0 ||
          energy < bestEnergy ||
          (energy == bestEnergy && distance < bestDistance)) {
        bestEnergy = energy;
        bestDistance = distance;
        bestStart = pos;
      }
    }
    if (bestStart < 0) return null;
    return bestStart;
  }

  /// 平均绝对振幅（16bit PCM，多声道取平均）；越界返回 -1（放弃静音搜索）。
  ///
  /// [frameBytes] 为一个采样帧的字节数：每个 16bit 声道样本长 2 字节，
  /// 因此按 `2 * frameBytes` 步进即取每帧第一声道的样本。
  static int _energy(
    List<int> pcm,
    int offset,
    int byteCount,
    int frameBytes,
  ) {
    final end = offset + byteCount;
    if (offset < 0 || end > pcm.length) return -1;
    var sum = 0;
    var count = 0;
    for (var pos = offset; pos + 1 < end; pos += 2 * frameBytes) {
      final sample = _s16(pcm, pos);
      sum += sample < 0 ? -sample : sample;
      count++;
    }
    if (count == 0) return -1;
    return sum ~/ count;
  }

  static Duration _timeAt(WavFormat format, int byteOffset) {
    final bytes = byteOffset - format.dataOffset;
    if (bytes <= 0) return Duration.zero;
    return Duration(
      microseconds:
          bytes * 1000000 ~/ (format.bytesPerFrame * format.sampleRate),
    );
  }

  /// 向下对齐到采样帧边界（相对 data 起始位置）。
  static int _floorToFrame(WavFormat format, int byteOffset) {
    final frame = format.bytesPerFrame;
    if (frame <= 1) return byteOffset;
    final relative = byteOffset - format.dataOffset;
    if (relative <= 0) return format.dataOffset;
    return format.dataOffset + (relative ~/ frame) * frame;
  }

  static String _tagAt(List<int> bytes, int offset) =>
      String.fromCharCodes(bytes.sublist(offset, offset + 4));

  static bool _tagEquals(List<int> bytes, int offset, String tag) =>
      _tagAt(bytes, offset) == tag;

  static int _u16(List<int> bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int _u32(List<int> bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);

  static int _s16(List<int> bytes, int offset) {
    final value = _u16(bytes, offset);
    return value >= 0x8000 ? value - 0x10000 : value;
  }
}
