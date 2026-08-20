import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/smart_canvas/services/card_action_router.dart';
import 'package:moodiary/features/smart_canvas/smart_canvas_logic.dart';
import 'package:moodiary/features/smart_canvas/states/block_list_state.dart';
import 'package:moodiary/features/smart_canvas/states/streaming_state.dart';

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
}
