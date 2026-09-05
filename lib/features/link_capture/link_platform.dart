/// 链接来源平台。
enum LinkPlatform { generalWeb, wechat, bilibili, douyin, unknown }

/// URL 识别器：根据主机名判断来源平台（与得到大脑「链接速记」对齐）。
class LinkRecognizer {
  LinkRecognizer._();

  static LinkPlatform recognize(String urlString) {
    final uri = Uri.tryParse(urlString.trim());
    if (uri == null || uri.host.isEmpty) return LinkPlatform.unknown;
    return fromHost(uri.host.toLowerCase());
  }

  static LinkPlatform fromHost(String host) {
    if (host.contains('mp.weixin.qq.com')) return LinkPlatform.wechat;
    if (host.contains('bilibili.com') ||
        host.contains('b23.tv') ||
        host.contains('biligame')) {
      return LinkPlatform.bilibili;
    }
    if (host.contains('douyin.com') ||
        host.contains('v.douyin.com') ||
        host.contains('iesdouyin.com')) {
      return LinkPlatform.douyin;
    }
    return LinkPlatform.generalWeb;
  }
}
