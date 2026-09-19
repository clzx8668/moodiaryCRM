import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/smart_canvas/services/diary_delete_service.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:uuid/uuid.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    // updateADiary 内部会读 Pref（WebDAV 开关），测试里给一份内存实现
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: PrefUtil.prefAllowList,
      ),
    );
    PrefUtil.overridePrefsForTest(prefs);
    // WebDavUtil.hasOption 直接对空值取 !，测试里给个空列表兜底
    await PrefUtil.setValue<List<String>>('webDavOption', <String>[]);
    db = openTestDb();
  });
  tearDown(() => closeTestDb(db));

  Future<Diary> seedDiary({String title = '待删除的记录'}) async {
    final now = DateTime(2026, 9, 19, 16, 40);
    final diary = Diary()
      ..id = const Uuid().v7()
      ..title = title
      ..contentText = '正文'
      ..content = '正文'
      ..type = 'markdown'
      ..time = now
      ..lastModified = now
      ..show = true
      ..mood = 0.5
      ..tags = ['测试'];
    await IsarUtil.insertADiary(diary);
    return diary;
  }

  Future<Block> seedBlock(String diaryId, {int sortOrder = 0}) async {
    final now = DateTime(2026, 9, 19, 16, 40);
    final block = Block()
      ..id = const Uuid().v7()
      ..diaryId = diaryId
      ..blockType = BlockType.text
      ..content = '卡片 $sortOrder'
      ..sortOrder = sortOrder
      ..createdAt = now
      ..updatedAt = now;
    await IsarUtil.insertBlock(block);
    return block;
  }

  test('删除一条记录：日记进回收站 + 子块全部软删（可恢复）', () async {
    final diary = await seedDiary();
    await seedBlock(diary.id, sortOrder: 0);
    await seedBlock(diary.id, sortOrder: 1);

    await DiaryDeleteService.moveToRecycle(
      diaryId: diary.id,
      isarId: diary.isarId,
    );

    // 日记从「在库」变成回收站
    final fresh = await IsarUtil.getDiaryById(diary.id);
    expect(fresh!.show, isFalse);
    final recycle = await IsarUtil.getRecycleBinDiaries();
    expect(recycle.map((d) => d.id), contains(diary.id));
    final visible = await IsarUtil.getAllDiariesSorted();
    expect(visible.map((d) => d.id), isNot(contains(diary.id)));

    // 子块软删：默认查询查不到，带 includeDeleted 能看到且标记为已删除
    expect(await IsarUtil.getBlocksByDiary(diary.id), isEmpty);
    final allBlocks = await IsarUtil.getBlocksByDiary(
      diary.id,
      includeDeleted: true,
    );
    expect(allBlocks.length, 2);
    expect(allBlocks.every((b) => b.isDeleted), isTrue);
  });

  test('只影响目标记录：其它笔记与卡片不受牵连', () async {
    final target = await seedDiary(title: '要删的');
    final keep = await seedDiary(title: '保留的');
    await seedBlock(target.id);
    await seedBlock(keep.id);

    await DiaryDeleteService.moveToRecycle(
      diaryId: target.id,
      isarId: target.isarId,
    );

    final keptDiary = await IsarUtil.getDiaryById(keep.id);
    expect(keptDiary!.show, isTrue);
    final keptBlocks = await IsarUtil.getBlocksByDiary(keep.id);
    expect(keptBlocks.length, 1);
    expect(keptBlocks.single.isDeleted, isFalse);
  });

  test('重复删除是幂等的（不会报错、状态一致）', () async {
    final diary = await seedDiary();
    await seedBlock(diary.id);

    await DiaryDeleteService.moveToRecycle(
      diaryId: diary.id,
      isarId: diary.isarId,
    );
    await DiaryDeleteService.moveToRecycle(
      diaryId: diary.id,
      isarId: diary.isarId,
    );

    final fresh = await IsarUtil.getDiaryById(diary.id);
    expect(fresh!.show, isFalse);
    final recycle = await IsarUtil.getRecycleBinDiaries();
    expect(recycle.where((d) => d.id == diary.id).length, 1);
  });
}
