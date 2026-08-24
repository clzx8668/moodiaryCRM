import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PackageUtil {
  //获取版本信息
  static Future<PackageInfo> getPackageInfo() async {
    // 平台通道超时兜底：避免首次启动在版本信息获取处永久挂起
    try {
      return await PackageInfo.fromPlatform().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      return PackageInfo(
        appName: '',
        packageName: '',
        version: '0.0.0',
        buildNumber: '0',
        buildSignature: '',
        installerStore: null,
      );
    }
  }

  static Future<BaseDeviceInfo> getInfo() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      return await deviceInfoPlugin.androidInfo;
    }
    if (Platform.isIOS) {
      return await deviceInfoPlugin.iosInfo;
    }
    if (Platform.isMacOS) {
      return await deviceInfoPlugin.macOsInfo;
    }
    if (Platform.isWindows) {
      return await deviceInfoPlugin.windowsInfo;
    }
    if (Platform.isLinux) {
      return await deviceInfoPlugin.linuxInfo;
    }
    return await deviceInfoPlugin.deviceInfo;
  }
}
