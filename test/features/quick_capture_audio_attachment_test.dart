import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';
import 'package:moodiary/features/quick_capture/quick_capture_saver.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: PrefUtil.prefAllowList,
      ),
    );
    PrefUtil.overridePrefsForTest(prefs);
    tempDir = Directory.systemTemp.createTempSync('quick_capture_audio');
    // 应用启动时 FileUtil 会建好 audio/image 等目录，测试里手动补上
    Directory('${tempDir.path}/audio').createSync(recursive: true);
    Directory('${tempDir.path}/image').createSync(recursive: true);
    await PrefUtil.setValue<String>('supportPath', tempDir.path);
    await PrefUtil.setValue<String>('cachePath', tempDir.path);
    await PrefUtil.setValue<List<String>>('webDavOption', <String>[]);
    db = openTestDb();
  });

  tearDown(() {
    closeTestDb(db);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('选了已有音频当附件：保存后入队音频转写（正文保持原文）', () async {
    final source = File('${tempDir.path}/pick.m4a')
      ..writeAsStringSync('fake-audio');

    final diary = await QuickCaptureSaver.save(
      text: '会议录音先存着',
      attachments: [
        QuickAttachment(
          path: source.path,
          type: QuickAttachmentType.audio,
          name: 'pick.m4a',
        ),
      ],
    );

    // 音频进入 audio 目录并挂在日记上
    expect(diary.audioName.length, 1);
    final saved = File('${tempDir.path}/audio/${diary.audioName.first}');
    expect(saved.existsSync(), isTrue);

    // 队列里出现 audio_transcribe（payload = 保存后的文件名）
    final tasks = await AiTaskRepository().listAll();
    final transcribe = tasks
        .where((t) => t.type == AiTaskType.audioTranscribe)
        .toList();
    expect(transcribe.length, 1);
    expect(transcribe.single.refId, diary.id);
    expect(transcribe.single.payload, diary.audioName.first);

    // 正文不被转写覆盖（转写结果落 AI 卡）
    final fresh = await IsarUtil.getDiaryById(diary.id);
    expect(fresh!.contentText, contains('会议录音先存着'));
  });

  test('没有音频附件时不会产生音频转写任务', () async {
    await QuickCaptureSaver.save(text: '纯文字速记', attachments: const []);
    final tasks = await AiTaskRepository().listAll();
    expect(tasks.where((t) => t.type == AiTaskType.audioTranscribe), isEmpty);
  });
}
