import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/smart_canvas/services/card_action_router.dart';
import 'package:moodiary/features/smart_canvas/smart_canvas_logic.dart';
import 'package:moodiary/features/smart_canvas/states/block_list_state.dart';
import 'package:moodiary/features/smart_canvas/states/streaming_state.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/db_test_helper.dart';

/// 测试流式 Provider：返回一段文本后完成
class FakeStreamProvider implements AiProvider {
  final String text;

  const FakeStreamProvider({this.text = 'AI 处理结果'});

  @override
  bool get isConfigured => true;

  @override
  Stream<AiChunk> streamTemplate({
    required String content,
    required String template,
  }) async* {
    yield AiChunk(text: text);
    yield const AiChunk(done: true);
  }

  @override
  Stream<AiChunk> streamChat(List<AiChatMessage> messages) async* {
    yield AiChunk(text: text);
    yield const AiChunk(done: true);
  }

  @override
  Future<AiChatCompletion> completeChat(
    List<AiChatMessage> messages, {
    List<AiToolDef>? tools,
  }) async {
    return AiChatCompletion(content: text);
  }

  @override
  Future<List<double>> embed(String text) async => [1.0, 0.0];
}

void main() {
  group('BlockListState', () {
    test('maxSortOrder 取最大排序号，空列表为 -1', () {
      final state = BlockListState();
      expect(state.maxSortOrder, -1);

      state.blocks.addAll([
        Block()..id = 'b1'..sortOrder = 2,
        Block()..id = 'b2'..sortOrder = 5,
      ]);
      expect(state.maxSortOrder, 5);
    });

    test('replace 按 id 局部替换', () {
      final state = BlockListState();
      state.blocks.add(Block()..id = 'b1'..content = '旧');
      state.replace(Block()..id = 'b1'..content = '新');
      expect(state.blocks.single.content, '新');
    });

    test('remove 按 id 摘除', () {
      final state = BlockListState();
      state.blocks.addAll([
        Block()..id = 'b1',
        Block()..id = 'b2',
      ]);
      state.remove('b1');
      expect(state.blocks.map((b) => b.id), ['b2']);
    });

    test('byId 查找', () {
      final state = BlockListState();
      state.blocks.add(Block()..id = 'b1');
      expect(state.byId('b1')?.id, 'b1');
      expect(state.byId('nope'), isNull);
    });
  });

  group('StreamingState', () {
    test('start/append/stop 状态机', () {
      final state = StreamingState();
      expect(state.streaming.value, isFalse);

      state.start('blk1');
      expect(state.streaming.value, isTrue);
      expect(state.streamingBlockId.value, 'blk1');
      expect(state.isStreaming('blk1'), isTrue);
      expect(state.isStreaming('other'), isFalse);

      state.append('你好');
      state.append('，世界');
      expect(state.buffer.value, '你好，世界');
      expect(state.sincePersist, 5);

      state.stop();
      expect(state.streaming.value, isFalse);
      expect(state.streamingBlockId.value, '');
    });

    test('持久化计数重置', () {
      final state = StreamingState()..start('b');
      state.append('12345');
      state.resetPersistCounter();
      expect(state.sincePersist, 0);
      expect(state.buffer.value, '12345');
    });
  });

  group('CardActionRouter', () {
    test('类型 → 动作映射', () {
      expect(resolveCardAction(Block()..blockType = BlockType.text), isA<MarkdownEditAction>());
      expect(
        resolveCardAction(Block()..blockType = BlockType.code),
        isA<MarkdownEditAction>(),
      );
      expect(
        resolveCardAction(Block()..blockType = BlockType.smartEntity),
        isA<EntityEditAction>(),
      );
      expect(
        resolveCardAction(Block()..blockType = BlockType.todo),
        isA<TodoToggleAction>(),
      );
      expect(
        resolveCardAction(Block()..blockType = BlockType.image),
        isA<ImagePreviewAction>(),
      );
      expect(
        resolveCardAction(Block()..blockType = BlockType.chart),
        isA<ChartViewAction>(),
      );
      expect(
        resolveCardAction(Block()..blockType = BlockType.aiStream),
        isA<AiStreamAction>(),
      );
    });
  });

  group('SmartCanvasLogic.todoListFromText', () {
    test('多行文本转任务清单', () {
      final result = SmartCanvasLogic.todoListFromText('寄样品\n回邮件\n约会议');
      expect(result, '- [ ] 寄样品\n- [ ] 回邮件\n- [ ] 约会议');
    });

    test('保留已有复选框前缀', () {
      final result = SmartCanvasLogic.todoListFromText('- [x] 已完成\n新任务');
      expect(result, '- [x] 已完成\n- [ ] 新任务');
    });

    test('空文本兜底', () {
      expect(SmartCanvasLogic.todoListFromText('  \n '), '- [ ] ');
    });
  });

  group('AiTemplates', () {
    test('Prompt 组装包含原文与模板指令', () {
      final prompt = AiTemplates.build(AiTemplates.polish, '这段文字需要润色');
      expect(prompt, contains('润色'));
      expect(prompt, contains('这段文字需要润色'));
    });

    test('所有模板都有非空 Prompt', () {
      for (final t in AiTemplates.all) {
        expect(AiTemplates.prompt(t), isNotEmpty, reason: '模板 $t');
        expect(AiTemplates.label(t), isNotEmpty, reason: '模板 $t');
      }
    });
  });

  group('SmartCanvasLogic AI 生命周期', () {
    test('aiProvider 可惰性替换（回归：构造后再初始化不再抛 LateInitializationError）', () {
      final logic = SmartCanvasLogic();
      expect(logic.aiProvider, isA<UnconfiguredAiProvider>());
      logic.aiProvider = const FakeStreamProvider();
      expect(logic.aiProvider, isA<FakeStreamProvider>());
    });

    test('runAiTemplate 完整生命周期：流式 → 转正（回归模板 AI 崩溃）', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: PrefUtil.prefAllowList,
        ),
      );
      await prefs.setStringList('webDavOption', []);
      await prefs.setBool('autoSyncAfterChange', false);
      PrefUtil.overridePrefsForTest(prefs);
      final db = openTestDb();
      addTearDown(() => closeTestDb(db));
      final diary = Diary()
        ..id = 'd-ai'
        ..title = '测试'
        ..content = '源内容'
        ..contentText = '源内容'
        ..type = 'markdown'
        ..time = DateTime(2026, 8, 20);
      await IsarUtil.insertADiary(diary);

      final logic = SmartCanvasLogic(aiProvider: const FakeStreamProvider());
      logic.canvasState.diary = diary;
      final source = Block()
        ..diaryId = diary.id
        ..content = '帮我总结一下';
      await logic.runAiTemplate(source, AiTemplates.summary);

      expect(logic.blockList.blocks, hasLength(1));
      final promoted = logic.blockList.blocks.first;
      expect(promoted.blockType, BlockType.text);
      expect(promoted.content, 'AI 处理结果');
      expect(promoted.streamComplete, isTrue);
    });
  });
}
