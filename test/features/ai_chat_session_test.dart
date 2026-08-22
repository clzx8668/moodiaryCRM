import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/models/ai_chat_session.dart';
import 'package:moodiary/features/rag/rag_service.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = openTestDb();
  });

  tearDown(() {
    closeTestDb(db);
  });

  test('会话与消息 CRUD + 引用来源往返', () async {
    final session = AiChatSession()
      ..id = 's1'
      ..title = '话题一';
    await IsarUtil.upsertChatSession(session);
    expect((await IsarUtil.getAllChatSessions()).length, 1);

    final msg = AiChatMessageRecord()
      ..sessionId = 's1'
      ..role = 'assistant'
      ..content = '回复内容'
      ..sources = [
        const RagHit(
          blockId: 'b1',
          diaryId: 'd1',
          knowledgeBaseId: 'kb',
          text: '引用源',
          score: 0.9,
        ),
      ];
    await IsarUtil.insertChatMessage(msg);

    final msgs = await IsarUtil.getChatMessages('s1');
    expect(msgs.length, 1);
    expect(msgs.first.content, '回复内容');
    expect(msgs.first.sources.single.blockId, 'b1');
    expect(msgs.first.sources.single.score, closeTo(0.9, 1e-6));

    await IsarUtil.deleteChatSession('s1');
    expect(await IsarUtil.getAllChatSessions(), isEmpty);
    expect(await IsarUtil.getChatMessages('s1'), isEmpty);
  });

  test('会话标题更新持久化', () async {
    final session = AiChatSession()..id = 's2';
    await IsarUtil.upsertChatSession(session);
    session.title = '改标题';
    await IsarUtil.upsertChatSession(session);
    final list = await IsarUtil.getAllChatSessions();
    expect(list.single.title, '改标题');
  });
}
