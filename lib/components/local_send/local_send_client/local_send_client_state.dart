import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/diary.dart';

class LocalSendClientState {
  int? serverPort;
  String? serverIp;
  String? serverName;

  Duration broadcastInterval = const Duration(seconds: 3);

  RxDouble progress = .0.obs;
  RxDouble speed = .0.obs;

  bool isFindingServer = false;

  /// 查找状态提示（含找不到时的操作指引）
  RxString findStatus = ''.obs;

  RxBool isSending = false.obs;
  RxList<Diary> diaryToSend = <Diary>[].obs;
  RxInt sendCount = 0.obs;

  LocalSendClientState();
}
