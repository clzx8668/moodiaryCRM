import 'dart:convert';
import 'dart:io';

import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:path/path.dart' as p;

/// 图片速记结果（对标得到大脑「智能拍书 / 拍照记录」）。
class VisionNoteResult {
  final String title;
  final String markdown;

  const VisionNoteResult({required this.title, required this.markdown});
}

/// 视觉 Prompt 构建（纯函数，便于单测）。
class VisionNotePrompts {
  VisionNotePrompts._();

  static const String system =
      '你是一个把图片整理成笔记的助手，用中文。只输出 JSON，不要多余说明。';

  static const String userPrompt = '''
请阅读这张图片（可能是书页、白板、PPT、截图或手写），完成：
1. 识别并保留全部关键文字（看不清就标注[?]）；
2. 整理成结构清晰的 Markdown 笔记（标题/要点/待办可选）；
3. 起一个 20 字以内的标题。
返回 JSON：{"title":"...","markdown":"..."}
''';
}

/// 图片速记服务：图片 → 视觉模型 → 结构化笔记文本。
class VisionCaptureService {
  VisionCaptureService._();

  static String mimeFor(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  /// 识别本地图片文件；失败返回 null（由调用方提示，不静默）。
  static Future<VisionNoteResult?> extractFile(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return extractBytes(bytes, imagePath);
  }

  static Future<VisionNoteResult?> extractBytes(
    List<int> bytes,
    String imagePath,
  ) async {
    if (bytes.isEmpty) return null;
    final provider = await AiProviderFactory.loadVision();
    if (!provider.isConfigured) return null;

    final dataUrl =
        'data:${mimeFor(imagePath)};base64,${base64Encode(bytes)}';
    final completion = await provider.completeChat([
      const AiChatMessage(role: 'system', content: VisionNotePrompts.system),
      AiChatMessage(
        role: 'user',
        content: VisionNotePrompts.userPrompt,
        images: [dataUrl],
      ),
    ]);
    return parseResult(completion.content);
  }

  /// 解析模型返回（JSON，容错代码围栏与纯文本）。
  static VisionNoteResult? parseResult(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    var s = t;
    final fence = RegExp(r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$').firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) {
        final markdown = decoded['markdown']?.toString().trim() ?? '';
        if (markdown.isNotEmpty) {
          return VisionNoteResult(
            title: decoded['title']?.toString().trim() ?? '',
            markdown: markdown,
          );
        }
      }
    } catch (_) {
      // 非 JSON 时按纯文本兜底
    }
    return VisionNoteResult(title: '', markdown: t);
  }
}
