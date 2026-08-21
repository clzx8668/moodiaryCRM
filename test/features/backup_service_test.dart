import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/ai/models/ai_chat_session.dart';
import 'package:moodiary/features/backup/backup_service.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/rag/models/block_embedding.dart';
import 'package:moodiary/features/rag/models/knowledge_base.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:path/path.dart' as p;

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() {
    db = openTestDb();
    tempDir = Directory.systemTemp.createTempSync('backup_test_');
  });

  tearDown(() async {
    closeTestDb(db);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> wipeAll() async {
    await db.transaction(() async {
      await db.delete(db.diaries).go();
      await db.delete(db.categories).go();
      await db.delete(db.blocks).go();
      await db.delete(db.crmEntityCaches).go();
      await db.delete(db.knowledgeBases).go();
      await db.delete(db.blockEmbeddings).go();
      await db.delete(db.aiChatSessions).go();
      await db.delete(db.aiChatMessages).go();
    });
  }

  test('导出→清空→导入：全量数据往返一致', () async {
    // 种子数据
    await IsarUtil.insertACategory(
      Category()
        ..id = 'cat1'
        ..categoryName = '工作',
    );
    final diary = Diary()
      ..id = 'd1'
      ..title = '客户拜访记录'
      ..content = '# 客户拜访记录\n今天拜访了张三。'
      ..contentText = '今天拜访了张三。'
      ..type = 'markdown'
      ..time = DateTime(2026, 8, 20, 10)
      ..mood = 0.8
      ..tags = ['客户'];
    await IsarUtil.insertADiary(diary);

    final textBlock = Block()
      ..id = 'b1'
      ..diaryId = 'd1'
      ..blockType = BlockType.text
      ..content = '今天拜访了张三，讨论了合同。'
      ..sortOrder = 0;
    final todoBlock = Block()
      ..id = 'b2'
      ..diaryId = 'd1'
      ..blockType = BlockType.todo
      ..content = '- [ ] 寄出样品'
      ..sortOrder = 1;
    todoBlock.meta = BlockMeta(
      source: BlockMeta.sourceAppended,
      aiTemplate: 'todo',
      dueDate: '2026-09-01T00:00:00.000',
    );
    await IsarUtil.insertBlocks([textBlock, todoBlock]);

    final company = CrmEntityCache()
      ..twentyId = 'twenty_1'
      ..entityType = 'company'
      ..name = '某某科技'
      ..setData({'name': '某某科技', 'address': '上海'});
    await IsarUtil.upsertCrmEntities([company]);

    final kb = KnowledgeBase()
      ..id = 'kb1'
      ..name = '产品知识库'
      ..description = '产品资料';
    await IsarUtil.upsertKnowledgeBase(kb);

    final embedding = BlockEmbedding()
      ..blockId = 'b1'
      ..diaryId = 'd1'
      ..knowledgeBaseId = 'kb1'
      ..text = '今天拜访了张三'
      ..embedding = Float32List.fromList([1.0, 2.0, 3.0, 4.0])
      ..updatedAt = DateTime(2026, 8, 20, 11);
    await IsarUtil.upsertBlockEmbedding(embedding);

    final session = AiChatSession()
      ..id = 's1'
      ..title = '客户跟进';
    await IsarUtil.upsertChatSession(session);
    final message = AiChatMessageRecord()
      ..id = 'm1'
      ..sessionId = 's1'
      ..role = 'user'
      ..content = '帮我整理拜访纪要';
    message.setSourcesJson(
      '[{"blockId":"b1","diaryId":"d1","knowledgeBaseId":"kb1",'
      '"text":"今天拜访了张三","score":0.9}]',
    );
    await IsarUtil.insertChatMessage(message);

    // 导出
    final zip = await BackupService.export(
      targetDirectory: tempDir.path,
    );
    expect(zip.existsSync(), isTrue);
    expect(zip.path, contains('moodiary_backup_'));

    // 清空后导入
    await wipeAll();
    final result = await BackupService.importFromFile(zip.path);
    expect(result.categories, 1);
    expect(result.diaries, 1);
    expect(result.blocks, 2);
    expect(result.crm, 1);
    expect(result.knowledgeBases, 1);
    expect(result.embeddings, 1);
    expect(result.sessions, 1);
    expect(result.messages, 1);

    // 抽查还原内容
    final restoredDiary = (await IsarUtil.getDiaryById('d1'))!;
    expect(restoredDiary.title, '客户拜访记录');
    expect(restoredDiary.mood, 0.8);
    expect(restoredDiary.tags, ['客户']);

    final restoredBlocks = await IsarUtil.getBlocksByDiary('d1');
    expect(restoredBlocks, hasLength(2));
    final restoredTodo = restoredBlocks.firstWhere(
      (b) => b.id == 'b2',
    );
    expect(restoredTodo.meta.aiTemplate, 'todo');
    expect(restoredTodo.meta.dueDate, '2026-09-01T00:00:00.000');

    final restoredCrm = await IsarUtil.getCrmEntitiesByType('company');
    expect(restoredCrm.single.data['address'], '上海');

    final restoredEmb = await IsarUtil.getAllBlockEmbeddings();
    expect(restoredEmb.single.embedding, Float32List.fromList([1, 2, 3, 4]));

    final restoredMessages = await IsarUtil.getChatMessages('s1');
    expect(restoredMessages.single.sources, isNotEmpty);
    expect(restoredMessages.single.sources.first.text, '今天拜访了张三');
  });

  test('导入幂等：重复导入不产生重复行', () async {
    final diary = Diary()
      ..id = 'd1'
      ..title = '唯一日记'
      ..content = '内容'
      ..contentText = '内容'
      ..type = 'markdown';
    await IsarUtil.insertADiary(diary);
    final zip = await BackupService.export(targetDirectory: tempDir.path);

    await BackupService.importFromFile(zip.path);
    await BackupService.importFromFile(zip.path);
    final all = await IsarUtil.getAllDiaries();
    expect(all.where((d) => d.id == 'd1'), hasLength(1));
  });

  test('缺失 manifest 报错', () async {
    await expectLater(
      BackupService.importFromFile(File(p.join(tempDir.path, 'x.zip')).path),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('extraJson 附加文件：导入后原样带回（AI 配置同步用）', () async {
    final zip = await BackupService.export(
      targetDirectory: tempDir.path,
      extraJson: {
        'ai_providers.json': [
          {
            'id': 'p1',
            'name': '测试服务',
            'baseUrl': 'https://example.com/v1',
            'apiKey': 'sk-test',
          },
        ],
        'ai_capabilities.json': {
          'chat': {'id': 'chat', 'enabled': true},
        },
      },
    );
    final result = await BackupService.importFromFile(zip.path);
    expect(result.extras['ai_providers.json'], isA<List>());
    final providers = result.extras['ai_providers.json'] as List;
    expect(providers, hasLength(1));
    expect(
      (providers.single as Map)['apiKey'],
      'sk-test',
    );
    expect(result.extras['ai_capabilities.json'], isA<Map>());
  });
}
