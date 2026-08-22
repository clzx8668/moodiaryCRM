import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/todo/todo_aggregator.dart';
import 'package:moodiary/features/todo/todo_item.dart';
import 'package:moodiary/features/todo/todo_parser.dart';

void main() {
  group('TodoParser.fromBlock', () {
    Block blockWith(String content) {
      return Block()
        ..id = 'blk_1'
        ..diaryId = 'diary_1'
        ..blockType = BlockType.todo
        ..content = content;
    }

    test('Markdown 行解析：未完成/已完成/忽略非任务行', () {
      final items = TodoParser.fromBlock(
        blockWith('- [ ] 寄出样品\n- [x] 回访客户\n普通说明\n* [ ] 整理合同'),
      );
      expect(items, hasLength(3));
      expect(items[0].text, '寄出样品');
      expect(items[0].done, isFalse);
      expect(items[1].text, '回访客户');
      expect(items[1].done, isTrue);
      expect(items[2].text, '整理合同');
      expect(items[2].lineIndex, 3);
      expect(items[0].isLocal, isTrue);
    });

    test('JSON 内容解析：单对象与数组', () {
      final single = TodoParser.fromBlock(
        blockWith('{"text": "张三跟进", "done": false}'),
      );
      expect(single, hasLength(1));
      expect(single.first.text, '张三跟进');

      final array = TodoParser.fromBlock(
        blockWith('[{"text":"A","done":true},{"title":"B","dueDate":"2026-09-01"}]'),
      );
      expect(array, hasLength(2));
      expect(array[0].done, isTrue);
      expect(array[1].dueDate, DateTime(2026, 9, 1));
    });

    test('meta.dueDate 映射到到期日', () {
      final block = blockWith('- [ ] 周三前完成');
      block.meta = BlockMeta(dueDate: '2026-08-25T00:00:00.000');
      final items = TodoParser.fromBlock(block);
      expect(items.single.dueDate, DateTime(2026, 8, 25));
    });

    test('toggleLine 仅改写指定行', () {
      const content = '- [ ] A\n- [x] B\n- [ ] C';
      final toggled = TodoParser.toggleLine(content, 1, done: false);
      expect(toggled, '- [ ] A\n- [ ] B\n- [ ] C');
      final toggled2 = TodoParser.toggleLine(toggled, 0, done: true);
      expect(toggled2, '- [x] A\n- [ ] B\n- [ ] C');
      expect(
        () => TodoParser.toggleLine(content, 5, done: true),
        throwsRangeError,
      );
    });
  });

  group('TodoParser.fromCrmTask', () {
    test('status DONE 与 completed=true 判定完成', () {
      final doneTask = CrmEntityCache()
        ..entityType = 'task'
        ..twentyId = 't1'
        ..name = '写周报'
        ..setData({'status': 'DONE'});
      final done = TodoParser.fromCrmTask(doneTask)!;
      expect(done.source, TodoSource.crmTask);
      expect(done.done, isTrue);
      expect(done.twentyId, 't1');

      final boolTask = CrmEntityCache()
        ..entityType = 'task'
        ..twentyId = 't2'
        ..name = '预约会议'
        ..setData({'completed': true, 'dueAt': '2026-08-30T10:00:00Z'});
      expect(TodoParser.fromCrmTask(boolTask)!.done, isTrue);
      expect(TodoParser.fromCrmTask(boolTask)!.dueDate, DateTime(2026, 8, 30));
    });

    test('非 task 类型 / 空名 / 已删除返回 null', () {
      expect(
        TodoParser.fromCrmTask(
          CrmEntityCache()..entityType = 'company'..name = '某某公司',
        ),
        isNull,
      );
      expect(
        TodoParser.fromCrmTask(CrmEntityCache()..entityType = 'task'),
        isNull,
      );
      expect(
        TodoParser.fromCrmTask(
          CrmEntityCache()
            ..entityType = 'task'
            ..name = '已删'
            ..isDeleted = true,
        ),
        isNull,
      );
    });
  });

  group('TodoAggregator.merge', () {
    test('本地 + CRM 合并，未完成在前，按日期升序', () {
      final blocks = [
        Block()
          ..id = 'b1'
          ..diaryId = 'd1'
          ..blockType = BlockType.todo
          ..content = '- [ ] 后做',
        Block()
          ..id = 'b2'
          ..diaryId = 'd2'
          ..blockType = BlockType.todo
          ..content = '- [x] 已完成',
      ];
      final tasks = [
        CrmEntityCache()
          ..entityType = 'task'
          ..twentyId = 't1'
          ..name = '最早任务'
          ..setData({'dueAt': '2026-08-01T00:00:00Z'}),
      ];
      final items = TodoAggregator.merge(
        todoBlocks: blocks,
        tasks: tasks,
      );
      expect(items, hasLength(3));
      // 未完成在前：后做 + 最早任务，然后已完成
      expect(items[0].text, '最早任务');
      expect(items[1].text, '后做');
      expect(items[2].text, '已完成');
    });

    test('includeDone=false 过滤已完成；date 按有效日期过滤', () {
      final blocks = [
        Block()
          ..id = 'b1'
          ..diaryId = 'd1'
          ..blockType = BlockType.todo
          ..content = '- [x] 昨天完成'
          ..updatedAt = DateTime(2026, 8, 19),
        Block()
          ..id = 'b2'
          ..diaryId = 'd2'
          ..blockType = BlockType.todo
          ..content = '- [ ] 今天待办'
          ..updatedAt = DateTime(2026, 8, 20),
      ];
      final open = TodoAggregator.merge(
        todoBlocks: blocks,
        tasks: const [],
        includeDone: false,
      );
      expect(open.single.text, '今天待办');

      final onDate = TodoAggregator.merge(
        todoBlocks: blocks,
        tasks: const [],
        date: DateTime(2026, 8, 19),
      );
      expect(onDate.single.text, '昨天完成');
    });

    test('空输入返回空列表', () {
      expect(
        TodoAggregator.merge(todoBlocks: const [], tasks: const []),
        isEmpty,
      );
    });
  });
}
