import 'dart:convert';
import 'dart:io';

import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart' as flutter;
import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/components/local_send/local_send_logic.dart';
import 'package:moodiary/features/ai/ai_capability_store.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/models/ai_capability_config.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';
import 'package:moodiary/features/backup/backup_service.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/pages/home/diary/diary_logic.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:moodiary/utils/wifi_multicast_lock.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

class LocalSendServerLogic extends GetxController {
  late RawDatagramSocket socket;
  HttpServer? httpServer;

  String? serverIp;
  String serverName = Faker().animal.name();

  RxDouble progress = .0.obs;

  RxDouble speed = .0.obs;
  RxInt receiveCount = 0.obs;

  late final LocalSendLogic localSendLogic = Bind.find<LocalSendLogic>();

  int get scanPort => localSendLogic.state.scanPort.value;

  int get transferPort => localSendLogic.state.transferPort.value;

  @override
  void onReady() async {
    // Android 接收端必须先持组播锁，否则收不到入站 UDP 广播
    await WifiMulticastLock.acquire();
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, scanPort);
    serverIp = await getDeviceIP();
    update();
    if (serverIp != null) {
      await startBroadcastListener();
      await startServer();
    } else {
      logger.i('无法获取本机 IP，接收服务未启动');
    }
    super.onReady();
  }

  @override
  void onClose() {
    socket.close();
    httpServer?.close(force: true);
    WifiMulticastLock.release();
    super.onClose();
  }

  // 启动UDP广播监听
  Future<void> startBroadcastListener() async {
    logger.i('Listening for broadcast on port $scanPort');
    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          final message = String.fromCharCodes(datagram.data);
          logger.i(
            'Received broadcast: $message from ${datagram.address.address}',
          );
          final response = '$serverIp:$transferPort:$serverName';
          socket.send(response.codeUnits, datagram.address, datagram.port);
        }
      }
    });
  }

  // 启动HTTP服务器
  Future<void> startServer() async {
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequest);
    // 绑定所有网卡而非仅 serverIp，避免 VPN/多网卡时 HTTP 监听错接口
    httpServer = await serve(handler, InternetAddress.anyIPv4, transferPort);
    logger.i('Server started on http://$serverIp:$transferPort');
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    late Diary diary;
    String? categoryName;
    final blocks = <Block>[];
    File? syncPacket;
    // 处理表单数据
    if (request.formData() case final form?) {
      await for (final formData in form.formData) {
        final name = formData.name;
        // 读取日记 JSON 数据
        if (name == 'diary') {
          diary = await flutter.compute(
            Diary.fromJson,
            jsonDecode(await formData.part.readString())
                as Map<String, dynamic>,
          );
        } else if (name == 'blocks') {
          // 双模态 Block（含待办/文本/实体卡）
          try {
            final list =
                jsonDecode(await formData.part.readString()) as List;
            blocks.addAll(
              list.map(
                (e) => Block.fromJson(e as Map<String, dynamic>),
              ),
            );
          } catch (_) {
            // 损坏的 blocks 字段忽略，不影响日记主体
          }
        } else if (name == 'file') {
          // 全量同步包（备份 zip 格式，含日记/Block/CRM/知识库/会话/AI 配置）
          final directory = p.join(FileUtil.getCachePath(''), 'lan_sync');
          await Directory(directory).create(recursive: true);
          final temp = File(
            p.join(
              directory,
              'sync_${DateTime.now().millisecondsSinceEpoch}.zip',
            ),
          );
          final sink = temp.openWrite();
          await formData.part.pipe(sink);
          await sink.close();
          syncPacket = temp;
        } else if (name == 'image' ||
            name == 'video' ||
            name == 'thumbnail' ||
            name == 'audio') {
          if (formData.filename != null) {
            // 写入文件到目录
            File file;
            if (name == 'thumbnail') {
              file = File(FileUtil.getRealPath('video', formData.filename!));
            } else {
              file = File(FileUtil.getRealPath(name, formData.filename!));
            }

            final sink = file.openWrite();
            await formData.part.pipe(sink);
            await sink.close();
          }
          // 如果有分类
        } else if (name == 'categoryName') {
          categoryName = await formData.part.readString();
        }
      }
    }
    // 全量同步包优先：解包合并后直接返回
    if (syncPacket != null) {
      try {
        final result = await BackupService.importFromFile(syncPacket.path);
        await _applyAiExtras(result.extras);
        await syncPacket.delete();
        logger.i('LAN sync packet imported: ${result.summary}');
        receiveCount.value += 1;
        try {
          await Bind.find<DiaryLogic>().refreshAll();
        } catch (_) {}
        return shelf.Response.ok('Data and files received successfully');
      } catch (e) {
        logger.i('LAN sync packet import failed: $e');
        return shelf.Response.internalServerError(
          body: 'Sync import failed: $e',
        );
      }
    }
    // 如果分类不为空，插入一个分类
    if (categoryName != null) {
      await IsarUtil.updateACategory(
        Category()
          ..id = diary.categoryId!
          ..categoryName = categoryName,
      );
    }
    // 插入日记
    await IsarUtil.insertADiary(diary);
    for (final block in blocks) {
      await IsarUtil.insertBlock(block);
    }
    await Bind.find<DiaryLogic>().refreshAll();
    receiveCount.value += 1;
    return shelf.Response.ok('Data and files received successfully');
  }

  /// 应用同步包内的 AI 服务商/能力配置（安全存储）
  Future<void> _applyAiExtras(Map<String, dynamic> extras) async {
    final providersRaw = extras['ai_providers.json'];
    if (providersRaw is List) {
      final providers = providersRaw
          .cast<Map<String, dynamic>>()
          .map(AiProviderConfig.fromJson)
          .toList();
      if (providers.isNotEmpty) {
        await AiProviderStore.saveAll(providers);
        logger.i('AI providers synced: ${providers.length}');
      }
    }
    final capabilitiesRaw = extras['ai_capabilities.json'];
    if (capabilitiesRaw is Map<String, dynamic>) {
      await AiCapabilityStore.save(AiCapabilitySet.fromJson(capabilitiesRaw));
      logger.i('AI capabilities synced');
    }
  }
}
