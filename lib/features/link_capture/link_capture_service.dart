import 'dart:convert';

import 'package:dio/dio.dart';

import 'captured_content.dart';
import 'link_html.dart';
import 'link_platform.dart';

/// 链接采集服务：识别平台 → 抓取 → 提取正文 → 生成保真 CapturedContent。
///
/// 设计原则：单条、用户主动触发；任何平台失败都降级为「链接+标题」，绝不静默失败。
/// 使用独立 Dio（不挂全局拦截器），避免网络失败弹全局错误提示。
class LinkCaptureService {
  LinkCaptureService._();

  static final LinkCaptureService instance = LinkCaptureService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (s) => s != null && s >= 200 && s < 400,
    ),
  );

  Future<CapturedContent> capture(String urlString) async {
    final url = _normalize(urlString);
    final platform = LinkRecognizer.recognize(url);
    try {
      switch (platform) {
        case LinkPlatform.wechat:
          return await _captureWechat(url);
        case LinkPlatform.bilibili:
          return await _captureBilibili(url);
        case LinkPlatform.douyin:
          return await _captureDouyin(url);
        default:
          return await _captureGeneral(url);
      }
    } catch (_) {
      return CapturedContent.fallback(url, url);
    }
  }

  String _normalize(String raw) {
    final t = raw.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    return 'https://$t';
  }

  Future<String> _getText(
    String url, {
    Map<String, String>? headers,
    bool followRedirects = true,
  }) async {
    final resp = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: headers,
        followRedirects: followRedirects,
      ),
    );
    return resp.data ?? '';
  }

  Future<Map<String, dynamic>> _getJson(
    String url, {
    Map<String, String>? headers,
  }) async {
    final resp = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: headers,
      ),
    );
    return jsonDecode(resp.data ?? '{}') as Map<String, dynamic>;
  }

  Future<CapturedContent> _captureGeneral(String url) async {
    final html = await _getText(
      url,
      headers: {'User-Agent': _desktopUa},
    );
    final title = LinkHtml.extractTitle(html);
    final text = LinkHtml.extractReadableText(html);
    return CapturedContent(
      url: url,
      title: title.isEmpty ? url : title,
      textContent: text,
      htmlContent: html,
      images: LinkHtml.extractImages(html),
      platform: LinkPlatform.generalWeb,
      capturedAt: DateTime.now(),
    );
  }

  Future<CapturedContent> _captureWechat(String url) async {
    final html = await _getText(
      url,
      headers: {
        'User-Agent': _wechatUa,
        'Referer': 'https://mp.weixin.qq.com/',
        'Accept-Language': 'zh-CN,zh;q=0.9',
      },
    );
    final title = LinkHtml.innerTextById(html, 'activity-name').isEmpty
        ? LinkHtml.extractTitle(html)
        : LinkHtml.innerTextById(html, 'activity-name');
    final author = LinkHtml.innerTextById(html, 'js_name');
    final content = LinkHtml.innerTextById(html, 'js_content');
    final text = content.isNotEmpty ? content : LinkHtml.extractReadableText(html);
    return CapturedContent(
      url: url,
      title: title.isEmpty ? url : title,
      author: author.isEmpty ? null : author,
      textContent: text,
      htmlContent: html,
      images: LinkHtml.extractImages(html),
      platform: LinkPlatform.wechat,
      capturedAt: DateTime.now(),
    );
  }

  Future<CapturedContent> _captureBilibili(String url) async {
    final bv = RegExp(r'BV[0-9A-Za-z]+').firstMatch(url)?.group(0) ?? '';
    if (bv.isEmpty) return CapturedContent.fallback(url, url);
    final api = 'https://api.bilibili.com/x/web-interface/view?bvid=$bv';
    final json = await _getJson(
      api,
      headers: {
        'User-Agent': _desktopUa,
        'Referer': 'https://www.bilibili.com',
      },
    );
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final title = data['title'] as String? ?? bv;
    final desc = (data['desc'] as String? ?? '').trim();
    final owner = ((data['owner'] as Map<String, dynamic>?) ?? {})['name'] as String?;
    final text = desc.isEmpty
        ? '（该视频无简介，仅保存基本信息）\n标题：$title'
        : desc;
    return CapturedContent(
      url: url,
      title: title,
      author: owner,
      textContent: text,
      platform: LinkPlatform.bilibili,
      capturedAt: DateTime.now(),
    );
  }

  Future<CapturedContent> _captureDouyin(String url) async {
    final html = await _getText(
      url,
      headers: {
        'User-Agent': _mobileUa,
      },
      followRedirects: true,
    );
    final title = _ogMeta(html, 'og:title') ?? _ogMeta(html, 'twitter:title') ?? url;
    final desc = _ogMeta(html, 'og:description') ?? _ogMeta(html, 'description') ?? '';
    final text = (title.isEmpty ? '' : '标题：$title\n') +
        (desc.isEmpty ? '（抖音内容暂无法自动提取，请手动粘贴文案）' : desc);
    return CapturedContent(
      url: url,
      title: title,
      textContent: text,
      platform: LinkPlatform.douyin,
      capturedAt: DateTime.now(),
    );
  }

  String? _ogMeta(String html, String property) {
    final m = RegExp(
      '<meta[^>]+property=["\']${RegExp.escape(property)}["\'][^>]+content=["\']([^"\']*)["\']',
      caseSensitive: false,
    ).firstMatch(html);
    return m?.group(1)?.trim();
  }

  static const String _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  static const String _mobileUa =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';

  static const String _wechatUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) MicroMessenger/8.0.49 Chrome/126.0.0.0 Safari/537.36';
}
