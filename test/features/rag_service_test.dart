import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/rag/models/block_embedding.dart';
import 'package:moodiary/features/rag/rag_service.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

import '../helpers/db_test_helper.dart';

/// 确定性测试 Provider：字符桶 embedding（相似文本向量接近）
class FakeEmbedProvider implements AiProvider {
  final int dimension;

  FakeEmbedProvider({this.dimension = 32});

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
}

void main() {
  late AppDatabase db;
  late RagService service;

  setUp(() {
    db = openTestDb();
    service = RagService()
      ..overrideProvider(FakeEmbedProvider(dimension: 32));
  });

  tearDown(() {
    closeTestDb(db);
  });

  Future<Block> insertBlock(
    String id, {
    String content = '内容',
    BlockType type = BlockType.text,
  }) async {
    final block = Block()
      ..id = id
      ..diaryId = 'd1'
      ..blockType = type
      ..content = content;
    await IsarUtil.insertBlock(block);
    return block;
  }

  test('知识库 CRUD', () async {
    expect(await service.listKnowledgeBases(), isEmpty);

    final kb = await service.createKnowledgeBase('客户库', description: '客户信息');
    expect(kb.name, '客户库');
    expect((await service.listKnowledgeBases()).length, 1);

    await service.deleteKnowledgeBase(kb.id);
    expect(await service.listKnowledgeBases(), isEmpty);
  });

  test('空名称知识库抛异常', () async {
    expect(
      () => service.createKnowledgeBase('   '),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('索引 Text 块并检索 topK', () async {
    final kb = await service.createKnowledgeBase('测试库');
    await insertBlock('b1', content: '苹果 香蕉 会议');
    await insertBlock('b2', content: '合同 回款 发票');
    await insertBlock('b3', content: '苹果 市场 增长', type: BlockType.todo);

    final indexed = await service.indexBlocks(knowledgeBaseId: kb.id);
    // text 参与索引；todo/未完成 aiStream 不参与
    expect(indexed, 2);
    expect(await service.countEmbeddings(kb.id), 2);

    final hits = await service.search(kb.id, '苹果', topK: 5);
    expect(hits, isNotEmpty);
    expect(hits.first.text, contains('苹果'));
    expect(hits.first.score, greaterThan(0));
  });

  test('删除块同步清除向量', () async {
    final kb = await service.createKnowledgeBase('测试库');
    await insertBlock('b1', content: '苹果');
    await insertBlock('b2', content: '香蕉');
    await service.indexBlocks(knowledgeBaseId: kb.id);
    expect(await service.countEmbeddings(kb.id), 2);

    await service.removeBlock(knowledgeBaseId: kb.id, blockId: 'b1');
    expect(await service.countEmbeddings(kb.id), 1);
  });

  test('buildContext 拼装参考内容与问题', () async {
    final kb = await service.createKnowledgeBase('测试库');
    await insertBlock('b1', content: '明天下午三点与张三开会');
    await insertBlock('b2', content: '寄送样品给李四');
    await service.indexBlocks(knowledgeBaseId: kb.id);

    final result = await service.buildContext(kb.id, '张三 会议');
    expect(result.context, contains('## 参考内容'));
    expect(result.context, contains('明天下午三点与张三开会'));
    expect(result.context, contains('## 问题'));
    expect(result.hits, isNotEmpty);
  });

  test('空知识库返回未检索到提示', () async {
    final kb = await service.createKnowledgeBase('空库');
    final result = await service.buildContext(kb.id, '随便问问');
    expect(result.hits, isEmpty);
    expect(result.context, contains('未检索到相关内容'));
  });

  test('cosine 基本行为', () {
    final a = Float32List.fromList([1, 0, 0]);
    final b = Float32List.fromList([0, 1, 0]);
    final same = Float32List.fromList([1, 0, 0]);
    expect(RagService.cosine(a, same), closeTo(1.0, 1e-6));
    expect(RagService.cosine(a, b), closeTo(0.0, 1e-6));
    expect(
      RagService.cosine(Float32List(3), Float32List(3)),
      closeTo(0.0, 1e-6),
    );
  });

  test('BlockEmbedding 字节编解码往返', () {
    final e = BlockEmbedding()
      ..blockId = 'b1'
      ..embedding = Float32List.fromList([1.5, -2.0, 3.25]);
    final raw = e.encode();
    final restored = BlockEmbedding.decode(raw, 3);
    expect(restored, isNot(null));
    expect(restored.length, 3);
    expect(restored[0], closeTo(1.5, 1e-5));
    expect(restored[2], closeTo(3.25, 1e-5));
  });
}
