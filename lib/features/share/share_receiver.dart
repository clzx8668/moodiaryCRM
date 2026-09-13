import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/link_capture/link_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 移动端系统分享接收（对标得到大脑「分享到 App」）。
///
/// 原生侧（MainActivity）通过 `share_channel` 把 ACTION_SEND 文本传入：
/// 含链接 → 走链接采集；否则当速记保存；随后刷新首页。
class ShareReceiver {
  ShareReceiver._();

  static const MethodChannel _channel = MethodChannel('share_channel');
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        await handleSharedText(call.arguments as String?);
      }
      return null;
    });
    try {
      // 冷启动时 App 由分享触发：取回启动 Intent 里的分享文本
      final initial = await _channel.invokeMethod<String>('getInitialShare');
      await handleSharedText(initial);
    } catch (_) {
      // 平台不支持（如桌面端）时静默跳过
    }
  }

  static Future<void> handleSharedText(String? raw) async {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return;
    try {
      final url = extractUrl(text);
      if (url != null) {
        await LinkCaptureSaver.saveFromUrl(url);
        toast.success(message: '已从分享保存链接笔记');
      } else {
        await QuickCaptureSaver.save(
          text: text,
          attachments: const <QuickAttachment>[],
        );
        toast.success(message: '已从分享保存速记');
      }
      if (Get.isRegistered<HomeLogic>()) {
        await Get.find<HomeLogic>().refreshDiaryLists();
      }
    } catch (e) {
      toast.error(message: '分享保存失败：$e');
    }
  }

  /// 从分享文本提取第一个 http(s) 链接（纯函数，可单测）。
  static String? extractUrl(String text) {
    final match = RegExp(r'https?://[^\s]+').firstMatch(text);
    if (match == null) return null;
    var url = match.group(0)!;
    // 去掉分享文案里常见的结尾标点
    url = url.replaceAll(RegExp(r'[)\]}>,，。；;、]+$'), '');
    return url.isEmpty ? null : url;
  }
}
