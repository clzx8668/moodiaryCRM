import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/local_send/local_send_client/local_send_client_logic.dart';
import 'package:moodiary/components/local_send/local_send_server/local_send_server_logic.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'local_send_state.dart';

Future<String?> getDeviceIP() async {
  // 优先 WiFi IP；失败时枚举网卡兜底（不依赖 connectivity 判定，
  // 避免探测异常导致服务端静默无法启动）
  try {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      final wifiIp = await NetworkInfo().getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) return wifiIp;
    }
  } catch (_) {
    // 忽略 connectivity 探测失败，继续兜底
  }

  final private = RegExp(r'^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)');
  try {
    // 优先私网 IPv4（局域网同步需要）
    for (final interface in await NetworkInterface.list()) {
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4 &&
            !address.isLoopback &&
            !address.isLinkLocal &&
            private.hasMatch(address.address)) {
          return address.address;
        }
      }
    }
    // 最后兜底：任意非回环 IPv4
    for (final interface in await NetworkInterface.list()) {
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4 &&
            !address.isLoopback) {
          return address.address;
        }
      }
    }
  } catch (_) {}

  return null; // 未连接网络或无法获取 IP 地址
}

class LocalSendLogic extends GetxController {
  final LocalSendState state = LocalSendState();

  @override
  void onReady() async {
    await getWifiInfo();
    super.onReady();
  }

  Future<void> getWifiInfo() async {
    state.deviceIpAddress = (await getDeviceIP()) ?? '无法获取';
    update(['WifiInfo']);
  }

  // // client
  // Future<void> findServer() async {
  //   state.findingServer.value = true;
  //   var serverInfo = await localSendClient.findServer();
  //   if (serverInfo != null) {
  //     state.serverIp.value = serverInfo['ip'];
  //     state.serverPort.value = serverInfo['port'];
  //     state.findingServer.value = false;
  //   }
  // }

  void showInfo() {
    state.showInfo = !state.showInfo;
    update(['Info']);
  }

  void changeType(String value) {
    state.type = value;
    update(['SegmentButton', 'Panel']);
  }

  void changeScanPort(int value) {
    state.scanPort.value = value;
    if (Bind.isRegistered<LocalSendServerLogic>()) {
      Bind.reload<LocalSendServerLogic>();
    }

    if (Bind.isRegistered<LocalSendClientLogic>()) {
      Bind.reload<LocalSendClientLogic>();
    }
  }

  void changeTransferPort(int value) {
    state.transferPort.value = value;

    if (Bind.isRegistered<LocalSendServerLogic>()) {
      Bind.reload<LocalSendServerLogic>();
    }

    if (Bind.isRegistered<LocalSendClientLogic>()) {
      Bind.reload<LocalSendClientLogic>();
    }
  }
}
