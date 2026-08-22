import 'dart:convert';
import 'dart:typed_data';

/// 块向量条目（P3.3：Text Block → Embedding）
class BlockEmbedding {
  String blockId = '';

  String diaryId = '';

  String knowledgeBaseId = '';

  /// 文本快照（重新向量化/摘要用）
  String text = '';

  /// 浮点向量（dimension 维）
  Float32List embedding = Float32List(0);

  int get dimension => embedding.length;

  DateTime updatedAt = DateTime.now();

  BlockEmbedding();

  /// 编码为 base64（Drift 文本列，规避 drift_dev 2.31 blob 解析问题）
  String encode() => base64Encode(embedding.buffer.asUint8List());

  /// 从 base64 解码（按维度切分）
  static Float32List decode(String raw, int dimension) {
    try {
      final bytes = base64Decode(raw);
      if (bytes.length != dimension * 4) {
        return Float32List(0);
      }
      return Float32List.view(bytes.buffer, bytes.offsetInBytes, dimension)
          .sublist(0);
    } catch (_) {
      return Float32List(0);
    }
  }
}
