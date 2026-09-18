import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/extract/ai_extract_meta.dart';
import 'package:moodiary/features/ai/extract/extract_plan_service.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';

void main() {
  group('ExtractPendingItem（待确认条目）', () {
    test('JSON 往返完整保留字段', () {
      const item = ExtractPendingItem(
        kind: 'schedule',
        title: '与李总开会',
        start: '2026-09-20T10:00',
        end: '2026-09-20T11:00',
        allDay: false,
        priority: '高',
        notes: '确认报价',
        remind: '提前 15 分钟',
      );
      final restored = ExtractPendingItem.fromJson(item.toJson());
      expect(restored.kind, 'schedule');
      expect(restored.title, '与李总开会');
      expect(restored.start, '2026-09-20T10:00');
      expect(restored.end, '2026-09-20T11:00');
      expect(restored.priority, '高');
      expect(restored.notes, '确认报价');
      expect(restored.remind, '提前 15 分钟');
      expect(restored.isTodo, isFalse);
    });

    test('无时间待办标记浮动', () {
      const item = ExtractPendingItem(
        kind: 'todo',
        title: '买打印纸',
        floating: true,
      );
      expect(item.isTodo, isTrue);
      expect(item.floating, isTrue);
      expect(ExtractPendingItem.fromJson(item.toJson()).floating, isTrue);
    });

    test('AiExtractMeta 读写待确认清单', () {
      final block = BlockFixture().block;
      AiExtractMeta.write(
        block,
        const AiExtractMeta(
          summary: '摘要',
          status: 'pending',
          pendingItems: [
            ExtractPendingItem(kind: 'todo', title: '回电李总'),
            ExtractPendingItem(kind: 'schedule', title: '周会', start: '2026-09-21T09:00'),
          ],
        ),
      );
      final meta = AiExtractMeta.read(block)!;
      expect(meta.status, 'pending');
      expect(meta.pendingItems, hasLength(2));
      expect(meta.pendingItems.first.title, '回电李总');
      expect(meta.summary, '摘要');
    });
  });

  group('ExtractPlanService.scheduleFromPending（确认后落库的预填对象）', () {
    test('待办：时间缺失则浮动、继承优先级与备注、写入双向关联', () {
      const item = ExtractPendingItem(
        kind: 'todo',
        title: '回复菲律宾项目进展',
        priority: '高',
        notes: '李总',
        floating: true,
      );
      final schedule = ExtractPlanService.scheduleFromPending(
        item,
        id: 'sid-1',
        diaryId: 'did-1',
        blockId: 'bid-1',
      );
      expect(schedule.id, 'sid-1');
      expect(schedule.title, '回复菲律宾项目进展');
      expect(schedule.floating, isTrue);
      expect(schedule.priority, SchedulePriority.high);
      expect(schedule.notes, '李总');
      expect(schedule.linkedDiaryId, 'did-1');
      expect(schedule.linkedBlockId, 'bid-1');
    });

    test('日程：解析开始/结束时间与提醒提前量', () {
      const item = ExtractPendingItem(
        kind: 'schedule',
        title: '客户周会',
        start: '2026-09-21T09:00:00',
        end: '2026-09-21T10:00:00',
        remind: '提前 15 分钟',
      );
      final schedule = ExtractPlanService.scheduleFromPending(
        item,
        id: 'sid-2',
        diaryId: 'did-2',
      );
      expect(schedule.startTime, DateTime(2026, 9, 21, 9));
      expect(schedule.endTime, DateTime(2026, 9, 21, 10));
      expect(schedule.remindOffsetMin, 15);
      expect(schedule.floating, isFalse);
    });
  });
}

/// 构造一个最小 Block（避免测试里到处写构造样板）。
class BlockFixture {
  final Block block = Block()
    ..diaryId = 'did'
    ..blockType = BlockType.text
    ..content = '正文';
}
