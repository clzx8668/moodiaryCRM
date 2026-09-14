import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/extract/extract_plan_service.dart';
import 'package:moodiary/features/ai/extract/extract_plan_types.dart';

void main() {
  group('ExtractPlanService.dedupe', () {
    test('同标题待办只保留一条（含空白/大小写差异）', () {
      const raw = ExtractPlanResult(
        actions: [
          ExtractAction(title: '给李总回复进展'),
          ExtractAction(title: '  给李总  回复进展 '),
          ExtractAction(title: '另一件事'),
        ],
      );
      final out = ExtractPlanService.dedupe(raw).result;
      expect(out.actions.length, 2);
      expect(out.actions.first.title, '给李总回复进展');
      expect(out.actions.last.title, '另一件事');
    });

    test('同标题日程只保留一条', () {
      const raw = ExtractPlanResult(
        events: [
          ExtractEvent(title: '项目评审会', start: '2026-09-15T09:00:00'),
          ExtractEvent(title: '项目评审会', start: '2026-09-15T10:00:00'),
        ],
      );
      final out = ExtractPlanService.dedupe(raw).result;
      expect(out.events.length, 1);
      expect(out.events.first.start, '2026-09-15T09:00:00');
    });

    test('待办与日程同标题：保留日程，并返回被合并的待办', () {
      const raw = ExtractPlanResult(
        actions: [
          ExtractAction(
            title: '给新加坡的李总回复菲律宾项目的进展',
            priority: '高',
            note: '早上发邮件',
          ),
        ],
        events: [
          ExtractEvent(
            title: '给新加坡的李总回复菲律宾项目的进展',
            start: '2026-09-15T09:00:00',
          ),
        ],
      );
      final deduped = ExtractPlanService.dedupe(raw);
      expect(deduped.result.actions, isEmpty);
      expect(deduped.result.events.length, 1);
      final merged = deduped.eventActions[
          ExtractPlanService.normalizeTitle('给新加坡的李总回复菲律宾项目的进展')];
      expect(merged, isNotNull);
      expect(merged!.priority, '高');
      expect(merged.note, '早上发邮件');
    });

    test('空标题被过滤，CRM/摘要保留', () {
      const raw = ExtractPlanResult(
        actions: [ExtractAction(title: '   ')],
        events: [ExtractEvent(title: '')],
        crm: [ExtractCrm(type: 'contact', name: '李总')],
        summary: '提醒明天上午9点回复李总',
      );
      final out = ExtractPlanService.dedupe(raw).result;
      expect(out.actions, isEmpty);
      expect(out.events, isEmpty);
      expect(out.crm.single.name, '李总');
      expect(out.summary, contains('上午9点'));
    });
  });
}

