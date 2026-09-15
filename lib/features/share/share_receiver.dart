import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/features/vision/quick_vision.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/link_capture/link_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/pages/edit/edit_arguments.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 移动端系统分享与桌面快捷方式接收（对标得到大脑「分享到 App」/ App Shortcuts）。
///
/// 原生侧（MainActivity）通过 `share_channel` 传入三类意图：
/// - ACTION_SEND 文本：含链接 → 链接采集，否则当速记保存；
/// - ACTION_SEND 图片（`EXTRA_STREAM`）：视觉整理成笔记（未配置视觉模型则退化为附件速记）；
/// - 长按图标快捷方式（`shortcut_id`）：语音速记 / 拍照速记 / 新建笔记。
/// 处理完都会刷新首页列表。
class ShareReceiver {
  ShareReceiver._();

  static const MethodChannel _channel = MethodChannel('share_channel');
  static bool _inited = false;

  /// 快捷方式 id（静态 shortcuts.xml 里的 shortcut_id）
  static const String shortcutVoice = 'voice';
  static const String shortcutCamera = 'camera';
  static const String shortcutNote = 'note';

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onShare':
          await handleSharedText(call.arguments as String?);
        case 'onShareImage':
          await handleSharedImage(call.arguments as String?);
        case 'onShortcut':
          await handleShortcut(call.arguments as String?);
      }
      return null;
    });
    try {
      // 冷启动时 App 由分享/快捷方式触发：取回启动 Intent 里的负载
      await handleSharedText(
        await _channel.invokeMethod<String>('getInitialShare'),
      );
      await handleSharedImage(
        await _channel.invokeMethod<String>('getInitialShareImage'),
      );
      await handleShortcut(
        await _channel.invokeMethod<String>('getInitialShortcut'),
      );
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

  /// 分享/传入的图片 → 视觉整理成笔记（未配置视觉模型则退化为附件速记）。
  static Future<void> handleSharedImage(String? path) async {
    final filePath = (path ?? '').trim();
    if (filePath.isEmpty) return;
    try {
      final diary = await QuickVisionActions.saveFromImagePath(filePath);
      if (diary == null) {
        toast.error(message: '分享的图片保存失败');
        return;
      }
      toast.success(message: '已从分享保存图片笔记「${diary.title}」');
      await _refreshHome();
    } catch (e) {
      toast.error(message: '分享图片失败：$e');
    }
  }

  /// 长按图标的快捷入口。
  static Future<void> handleShortcut(String? rawId) async {
    final id = normalizeShortcutId(rawId);
    if (id.isEmpty) return;
    switch (id) {
      case shortcutVoice:
        await Get.toNamed(AppRoutes.voiceRecordPage);
      case shortcutNote:
        await Get.toNamed(
          AppRoutes.editPage,
          arguments: const EditArguments(type: DiaryType.markdown),
        );
      case shortcutCamera:
        toast.info(message: '正在识别图片…');
        final diary = await QuickVisionActions.captureFromCamera();
        if (diary != null) {
          toast.success(message: '已生成图片笔记「${diary.title}」');
        }
        await _refreshHome();
    }
  }

  /// 快捷方式 id 规范化（纯函数，可单测）：未知/空 → 空串。
  static String normalizeShortcutId(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case shortcutVoice:
        return shortcutVoice;
      case shortcutCamera:
        return shortcutCamera;
      case shortcutNote:
        return shortcutNote;
      default:
        return '';
    }
  }

  static Future<void> _refreshHome() async {
    if (Get.isRegistered<HomeLogic>()) {
      await Get.find<HomeLogic>().refreshDiaryLists();
    }
  }
}
