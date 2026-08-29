import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/health/health_service.dart';
import 'package:moodiary/features/rag/models/knowledge_base.dart';
import 'package:moodiary/features/rag/rag_service.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

import '../helpers/db_test_helper.dart';

/// 确定性测试 Provider（与 rag_service_test 同款字符桶 embedding）
class _FakeEmbedProvider implements AiProvider {
  final int dimension;

  _FakeEmbedProvider({this.dimension = 8});

  @override
  bool get isConfigured => true;

  @override
  Future<List<double>> embed(String text) async {
    final v = List<double>.filled(dimension, 0);
    for (final c in text.runes) {
      v[c % dimension] += 1;
    }
    return v;
  }

  @override
  Stream<AiChunk> streamTemplate({
    required String content,
    required String template,
  }) {
    return const Stream.empty();
  }

  @override
  Stream<AiChunk> streamChat(List<AiChatMessage> messages) {
    return const Stream.empty();
  }

  @override
  Future<AiChatCompletion> completeChat(
    List<AiChatMessage> messages, {
    List<AiToolDef>? tools,
  }) async {
    return const AiChatCompletion();
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = openTestDb();
  });

  tearDown(() {
    closeTestDb(db);
  });

  test('loadStats 汇总日记/Block/CRM/知识库/向量计数', () async {
    final diary = Diary()
      ..id = 'd1'
      ..title = '笔记'
      ..content = '内容'
      ..contentText = '内容'
      ..type = 'markdown';
    await IsarUtil.insertADiary(diary);
    await IsarUtil.insertBlock(
      Block()
        ..id = 'b1'
        ..diaryId = 'd1'
        ..blockType = BlockType.text
        ..content = '正文',
    );
    await IsarUtil.upsertCrmEntities([
      CrmEntityCache()
        ..twentyId = 't1'
        ..entityType = 'company'
        ..name = '某某公司',
    ]);
    await IsarUtil.upsertKnowledgeBase(
      KnowledgeBase()
        ..id = 'kb1'
        ..name = '产品知识库',
    );

    final stats = await HealthService.loadStats();
    expect(stats.diaries, 1);
    expect(stats.blocks, 1);
    expect(stats.crmEntities, 1);
    expect(stats.knowledgeBases, 1);
    expect(stats.embeddings, 0);
    expect(stats.dbSizeText, isNotEmpty);
  });

  test('reindexAll 遍历全部知识库并写入向量', () async {
    final rag = RagService()
      ..overrideProvider(_FakeEmbedProvider(dimension: 8));
    await IsarUtil.upsertKnowledgeBase(
      KnowledgeBase()
        ..id = 'kb1'
        ..name = '知识库一',
    );
    final diary = Diary()
      ..id = 'd1'
      ..title = '标题'
      ..content = 'hello world'
      ..contentText = 'hello world'
      ..type = 'markdown';
    await IsarUtil.insertADiary(diary);
    await IsarUtil.insertBlock(
      Block()
        ..id = 'b1'
        ..diaryId = 'd1'
        ..blockType = BlockType.text
        ..content = 'hello world',
    );

    final result = await rag.reindexAll();
    expect(result.knowledgeBases, 1);
    expect(result.succeeded, 1);
    expect(result.indexed, 1);
    expect(await IsarUtil.countEmbeddingsByKnowledgeBase('kb1'), 1);
  });
}
