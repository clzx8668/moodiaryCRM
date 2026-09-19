import 'package:moodiary/features/attachments/attachment_manager.dart';

/// Markdown 链接的落点类型。
enum MarkdownLinkKind {
  /// http(s) 外链 → 系统浏览器
  external,

  /// 本地附件（Attachments 下的相对路径）→ 系统应用（或复制路径兜底）
  local,

  /// 空 / 无法识别
  invalid,
}

/// 解析 Markdown 链接（纯函数，便于单测）。
///
/// 正文里的附件是 `- 📎 [名称](documents/2026/09/xxx.pdf)` 这种**相对路径**，
/// 需要先解析到沙盒绝对路径才能交给系统打开。
class MarkdownLink {
  MarkdownLink._();

  static MarkdownLinkKind kindOf(String url) {
    final text = url.trim();
    if (text.isEmpty) return MarkdownLinkKind.invalid;
    final uri = Uri.tryParse(text);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return MarkdownLinkKind.external;
    }
    // 带协议但非 http(s)（mailto/tel 等）按外链交给系统
    if (uri != null && uri.scheme.isNotEmpty && uri.scheme != 'file') {
      return MarkdownLinkKind.external;
    }
    return MarkdownLinkKind.local;
  }

  /// 本地附件的绝对路径；非本地链接返回 null。
  static String? localPathOf(String url) {
    if (kindOf(url) != MarkdownLinkKind.local) return null;
    var relative = url.trim();
    if (relative.startsWith('file://')) {
      relative = relative.substring('file://'.length);
    }
    relative = relative.replaceAll('\\', '/');
    while (relative.startsWith('/')) {
      relative = relative.substring(1);
    }
    if (relative.isEmpty) return null;
    return AttachmentManager.resolvePath(relative);
  }
}
