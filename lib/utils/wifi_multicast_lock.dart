import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android 广播/组播接收锁（WifiManager.MulticastLock）。
///
/// 局域网同步的接收端必须持有该锁，否则 Android Wi-Fi 驱动会丢弃入站 UDP 广播，
/// 表现为「找不到服务器」（发送端 Broadcast sent 但接收端毫无反应）。
/// Windows/macOS/Linux 无需持锁，调用自动忽略。
class WifiMulticastLock {
  static const MethodChannel _channel = MethodChannel('wifi_multicast_channel');

  /// 引用计数：客户端与接收端可能同时调用，防止提前释放
  static int _holders = 0;

  static Future<void> acquire() async {
    if (kIsWeb || !Platform.isAndroid) return;
    _holders++;
    if (_holders > 1) return; // 已有调用方持有
    try {
      await _channel.invokeMethod<bool>('acquire');
    } catch (_) {
      // 权限缺失或设备不支持时静默降级，不影响其他平台
    }
  }

  static Future<void> release() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_holders <= 0) return;
    _holders--;
    if (_holders > 0) return;
    try {
      await _channel.invokeMethod<bool>('release');
    } catch (_) {}
  }
}
