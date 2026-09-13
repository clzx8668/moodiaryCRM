import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'link_html.dart';

/// WebView 渲染结果（标题 + 正文）。
class WebRenderResult {
  final String title;
  final String text;

  const WebRenderResult({required this.title, required this.text});
}

/// SPA 兜底：普通 HTTP 抓不到正文（需 JS 渲染）时，用无头 WebView 渲染后取 DOM 文本。
///
/// - 复用既有 `flutter_inappwebview`（Android 系统 WebView / Windows WebView2），不新增依赖；
/// - 任何失败/超时返回 null，调用方保留原 HTTP 结果（不静默丢内容）；
/// - `shouldFallback` / `parseRenderResult` 为纯函数，便于单测。
class WebRenderService {
  WebRenderService._();

  /// 正文短于该长度时认为需要渲染兜底。
  static const int minTextLength = 200;

  static bool shouldFallback(String text) =>
      LinkHtml.collapse(text).length < minTextLength;

  /// 解析 WebView 返回值（JSON 字符串或 Map）。
  static WebRenderResult? parseRenderResult(dynamic raw) {
    if (raw == null) return null;
    dynamic decoded = raw;
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      try {
        decoded = jsonDecode(s);
      } catch (_) {
        return null;
      }
    }
    if (decoded is Map) {
      final title = LinkHtml.collapse((decoded['title'] ?? '').toString());
      final text = LinkHtml.collapse((decoded['text'] ?? '').toString());
      if (text.isEmpty) return null;
      return WebRenderResult(title: title, text: text);
    }
    return null;
  }

  static const String _extractJs = r'''
(function () {
  try {
    var t = document.title || '';
    var b = document.body ? (document.body.innerText || document.body.textContent || '') : '';
    return JSON.stringify({ title: t, text: b });
  } catch (e) { return ''; }
})();
''';

  /// 渲染指定 URL 并返回正文；超时/失败返回 null。
  static Future<WebRenderResult?> render(
    String url, {
    Duration timeout = const Duration(seconds: 18),
  }) async {
    final completer = Completer<WebRenderResult?>();
    HeadlessInAppWebView? headless;
    Timer? timer;

    Future<void> finish(WebRenderResult? result) async {
      if (!completer.isCompleted) completer.complete(result);
      timer?.cancel();
      try {
        await headless?.dispose();
      } catch (_) {
        // 忽略释放异常
      }
    }

    try {
      headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          transparentBackground: true,
        ),
        onLoadStop: (controller, uri) async {
          try {
            final raw = await controller.evaluateJavascript(source: _extractJs);
            await finish(parseRenderResult(raw));
          } catch (_) {
            await finish(null);
          }
        },
        onReceivedError: (controller, request, error) async {
          await finish(null);
        },
      );
      timer = Timer(timeout, () => finish(null));
      await headless.run();
      return await completer.future;
    } catch (_) {
      await finish(null);
      return completer.future;
    }
  }
}
