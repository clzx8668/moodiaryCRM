import 'dart:io';
import 'dart:typed_data';

/// 边录边写 WAV：先写 44 字节头（长度先占位），音频块顺序追加，
/// 收尾时回填真实长度。用于"端侧实时转写"模式（PCM 流 ⇒ 既要实时喂模型、
/// 也要留下可回放/可上传的音频文件）。
///
/// 纯文件 IO，可在单测里用临时目录验证头字段。
class WavWriter {
  WavWriter({
    required this.path,
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitsPerSample = 16,
  });

  final String path;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;

  RandomAccessFile? _file;
  int _dataBytes = 0;
  bool _closed = false;

  /// 已写入的音频字节数（不含头）
  int get dataBytes => _dataBytes;

  /// 时长（按已写入字节数估算）
  Duration get duration => Duration(
    milliseconds:
        (dataBytes / (sampleRate * channels * (bitsPerSample ~/ 8)) * 1000)
            .round(),
  );

  Future<void> open() async {
    final file = File(path);
    await file.create(recursive: true);
    _file = await file.open(mode: FileMode.write);
    await _file!.writeFrom(_header(dataBytes: 0));
  }

  Future<void> add(Uint8List pcm) async {
    final file = _file;
    if (file == null || _closed || pcm.isEmpty) return;
    await file.writeFrom(pcm);
    _dataBytes += pcm.length;
  }

  /// 收尾：回填头部长度并关闭
  Future<int> close() async {
    final file = _file;
    if (file == null || _closed) return _dataBytes;
    _closed = true;
    await file.setPosition(0);
    await file.writeFrom(_header(dataBytes: _dataBytes));
    await file.close();
    _file = null;
    return _dataBytes;
  }

  /// 44 字节 WAV 头（纯函数，便于断言）
  Uint8List _header({required int dataBytes}) {
    const headerSize = 44;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final data = ByteData(headerSize);
    var offset = 0;
    void ascii(String s) {
      for (final c in s.codeUnits) {
        data.setUint8(offset++, c);
      }
    }

    ascii('RIFF');
    data.setUint32(offset, 36 + dataBytes, Endian.little);
    offset += 4;
    ascii('WAVE');
    ascii('fmt ');
    data.setUint32(offset, 16, Endian.little); // PCM 子块大小
    offset += 4;
    data.setUint16(offset, 1, Endian.little); // PCM
    offset += 2;
    data.setUint16(offset, channels, Endian.little);
    offset += 2;
    data.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    data.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    data.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    data.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;
    ascii('data');
    data.setUint32(offset, dataBytes, Endian.little);
    return data.buffer.asUint8List();
  }
}
