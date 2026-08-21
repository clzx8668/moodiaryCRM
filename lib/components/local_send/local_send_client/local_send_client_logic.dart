import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/local_send/local_send_logic.dart';
import 'package:moodiary/features/ai/ai_capability_store.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/backup/backup_service.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/http_util.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:moodiary/utils/send_util.dart';
import 'package:moodiary/utils/wifi_multicast_lock.dart';

import 'local_send_client_state.dart';

class LocalSendClientLogic extends GetxController {
  final LocalSendClientState state = LocalSendClientState();

  late RawDatagramSocket socket;
  Timer? timer;
  late final LocalSendLogic localSendLogic = Bind.find<LocalSendLogic>();

  int get scanPort => localSendLogic.state.scanPort.value;

  @override
  void onReady() async {
    super.onReady();
    await WifiMulticastLock.acquire();
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    await startFindServer();
  }

  @override
  void onClose() {
    socket.close();
    timer?.cancel();
    WifiMulticastLock.release();
    super.onClose();
  }

  Future<void> _sendBroadcast() async {
    const message = 'Looking for server';
    // 目标集合：全局广播 + 各网卡定向广播（部分网络/路由器会丢弃 255.255.255.255）
    final targets = <InternetAddress>{
      InternetAddress('255.255.255.255'),
    };
    try {
      for (final interface in await NetworkInterface.list()) {
        for (final address in interface.addresses) {
          // 该 SDK 的 addresses 为 InternetAddress，无 netmask；
          // 按常见 /24 私网推导定向广播（如 192.168.1.x → 192.168.1.255）
          if (address.type == InternetAddressType.IPv4 &&
              !address.isLoopback) {
            final parts = address.address.split('.');
            if (parts.length == 4) {
              parts[3] = '255';
              targets.add(InternetAddress(parts.join('.')));
            }
          }
        }
      }
    } catch (_) {
      // 枚举网卡失败时仅使用全局广播
    }
    for (final target in targets) {
      try {
        socket.send(message.codeUnits, target, scanPort);
      } catch (e) {
        logger.i('Broadcast to ${target.address} failed: $e');
      }
    }
    logger.i('Broadcast sent to ${targets.map((t) => t.address).join(', ')}');
  }

  // 尝试在 30 秒内找到服务器
  Future<bool> startFindServer() async {
    state.isFindingServer = true;
    update();

    final found = await _findServer(timeout: const Duration(seconds: 30));

    if (found) {
    } else {
      state.isFindingServer = false;
      update();
    }
    return found;
  }

  // 重新开始查找服务器
  Future<void> restartFindServer() async {
    // 确保之前的监听已停止
    timer?.cancel();
    socket.close();

    // 重新初始化 socket 和监听
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    await startFindServer();
  }

  Future<bool> _findServer({required Duration timeout}) async {
    final completer = Completer<bool>();

    // 启动 30 秒超时定时器
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        timer?.cancel();
        state.findStatus.value =
            '未找到接收端：请确认另一台设备已打开「接收」标签、两台设备处于同一局域网，'
            '且防火墙放行了 $scanPort（扫描）与 ${localSendLogic.state.transferPort.value}（传输）端口；'
            '若使用路由器/访客 Wi-Fi 请检查是否开启了 AP 隔离。';
        completer.complete(false);
      }
    });

    // 轮询发送广播消息
    timer = Timer.periodic(state.broadcastInterval, (timer) {
      _sendBroadcast();
    });

    // 监听服务器响应
    socket.listen((RawSocketEvent event) async {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          final serverResponse = String.fromCharCodes(datagram.data);
          logger.i('Found server: $serverResponse');

          final serverInfo = serverResponse.split(':');
          state.serverIp = serverInfo[0];
          state.serverPort = int.parse(serverInfo[1]);
          state.serverName = serverInfo[2];
          state.findStatus.value =
              '已找到服务器：${state.serverName}（${state.serverIp}:${state.serverPort}）';
          state.isFindingServer = false;
          update();

          timer?.cancel();
          socket.close();

          if (!completer.isCompleted) {
            completer.complete(true);
          }
        }
      }
    });

    // 初次发送广播
    _sendBroadcast();
    state.findStatus.value = '正在查找服务器…';

    return completer.future;
  }

  // 向服务器发送数据并监听进度
  Future<void> sendData(Diary diary) async {
    state.isSending.value = true;
    // 创建 FormData 并同步添加 JSON 和文件
    final dio.FormData formData = dio.FormData();
    // 添加 JSON 数据
    formData.fields.add(MapEntry('diary', jsonEncode(diary.toJson())));
    // 双模态 Block（含待办/文本/实体卡），保证对端日历待办与详情页一致
    final blocks = await IsarUtil.getBlocksByDiary(diary.id);
    formData.fields.add(
      MapEntry(
        'blocks',
        jsonEncode([for (final block in blocks) block.toJson()]),
      ),
    );
    // 如果有分类，把分类名字带过去
    if (diary.categoryId != null) {
      final categoryName =
          IsarUtil.getCategoryName(diary.categoryId!)!.categoryName;
      formData.fields.add(MapEntry('categoryName', categoryName));
    }
    // 同步添加图片文件
    for (final imageName in diary.imageName) {
      final filePath = FileUtil.getRealPath('image', imageName);
      formData.files.add(
        MapEntry(
          'image',
          await dio.MultipartFile.fromFile(filePath, filename: imageName),
        ),
      );
    }
    // 同步添加视频文件
    for (final videoName in diary.videoName) {
      final filePath = FileUtil.getRealPath('video', videoName);
      formData.files.add(
        MapEntry(
          'video',
          await dio.MultipartFile.fromFile(filePath, filename: videoName),
        ),
      );
    }
    // 同步添加缩略图文件
    for (final videoName in diary.videoName) {
      final filePath = FileUtil.getRealPath('thumbnail', videoName);
      formData.files.add(
        MapEntry(
          'thumbnail',
          await dio.MultipartFile.fromFile(
            filePath,
            filename: 'thumbnail-${videoName.substring(6, 42)}.jpeg',
          ),
        ),
      );
    }
    // 同步添加音频文件
    for (final audioName in diary.audioName) {
      final filePath = FileUtil.getRealPath('audio', audioName);
      formData.files.add(
        MapEntry(
          'audio',
          await dio.MultipartFile.fromFile(filePath, filename: audioName),
        ),
      );
    }
    final uploadSpeedCalculator = UploadSpeedCalculator();
    final response = await HttpUtil().upload(
      'http://${state.serverIp}:${state.serverPort}',
      data: formData,
      onSendProgress: (int sent, int total) {
        uploadSpeedCalculator.updateSpeed(sent);
        state.speed.value = uploadSpeedCalculator.getSpeed();
        state.progress.value = sent / total;
      },
    );
    if (response.statusCode == 200 && response.data != null) {
    } else {
      toast.error(message: '发送失败');
    }
    state.sendCount.value += 1;
  }

  Future<void> sendDiaryList() async {
    if (state.diaryToSend.isNotEmpty) {
      for (final diary in state.diaryToSend) {
        await sendData(diary);
        state.progress.value = .0;
      }
      state.sendCount.value = 0;
      state.diaryToSend.clear();
      state.isSending.value = false;
      toast.success(message: '发送完成');
    } else {
      toast.info(message: '还没选择日记');
    }
  }

  /// 全量同步：打包 日记+Block+CRM+知识库+向量+AI 会话/AI 配置 为 zip 发送。
  Future<void> sendAllData() async {
    state.isSending.value = true;
    try {
      toast.info(message: '正在打包同步数据…');
      final packet = await BackupService.export(
        targetDirectory: FileUtil.getCachePath('lan_sync'),
        extraJson: await _buildAiExtras(),
      );

      final dio.FormData formData = dio.FormData();
      formData.files.add(
        MapEntry(
          'file',
          await dio.MultipartFile.fromFile(
            packet.path,
            filename: packet.path.split(Platform.pathSeparator).last,
          ),
        ),
      );

      final uploadSpeedCalculator = UploadSpeedCalculator();
      final response = await HttpUtil().upload(
        'http://${state.serverIp}:${state.serverPort}',
        data: formData,
        onSendProgress: (int sent, int total) {
          uploadSpeedCalculator.updateSpeed(sent);
          final speed = uploadSpeedCalculator.getSpeed();
          state.speed.value = speed;
          state.progress.value = sent / total;
        },
      );
      if (response.statusCode == 200 &&
          response.data == 'Data and files received successfully') {
        toast.success(message: '同步完成：多端数据已合并');
      } else {
        toast.error(message: '同步失败');
      }
      await packet.delete();
    } catch (e) {
      toast.error(message: '同步失败：$e');
    } finally {
      state.isSending.value = false;
    }
  }

  /// AI 服务商 + 能力配置（安全存储）打包为同步附加 JSON
  Future<Map<String, Object>> _buildAiExtras() async {
    final extras = <String, Object>{};
    try {
      final providers = await AiProviderStore.loadAll();
      extras['ai_providers.json'] = [
        for (final provider in providers) provider.toJson(),
      ];
    } catch (_) {
      // 安全存储不可用（如测试环境）时跳过配置同步
    }
    try {
      extras['ai_capabilities.json'] = (await AiCapabilityStore.load()).toJson();
    } catch (_) {}
    return extras;
  }

  Future<void> setDiary(Duration duration, BuildContext context) async {
    Navigator.pop(context);
    final now = DateTime.now();
    state.diaryToSend.value = await IsarUtil.getDiariesByDateRange(
      now.subtract(duration),
      now,
    );
  }

  Future<void> setAllDiary(BuildContext context) async {
    Navigator.pop(context);
    state.diaryToSend.value = await IsarUtil.getAllDiaries();
  }
}
