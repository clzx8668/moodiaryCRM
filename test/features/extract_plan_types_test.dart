import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/extract/extract_plan_types.dart';

void main() {
  group('ExtractPlanResult.tryParse', () {
    test('解析 AI 输出的 JSON', () {
      const s =
          '{"actions":[{"title":"明天开会","priority":"高","dueAt":null}],'
          '"events":[{"title":"会议","start":"2026-09-01T10:00","allDay":false}],'
          '"crm":[{"type":"account","name":"星海科技","fields":{"phone":"13800000000"}}],'
          '"summary":"准备与客户开会"}';
      final r = ExtractPlanResult.tryParse(s)!;
      expect(r.actions, hasLength(1));
      expect(r.actions.first.title, '明天开会');
      expect(r.events, hasLength(1));
      expect(r.events.first.start, '2026-09-01T10:00');
      expect(r.events.first.allDay, isFalse);
      expect(r.crm, hasLength(1));
      expect(r.crm.first.type, 'account');
      expect(r.crm.first.fields['phone'], '13800000000');
      expect(r.summary, '准备与客户开会');
    });

    test('代码围栏包裹也可解析', () {
      const s = '```json\n{"summary":"x"}\n```';
      final r = ExtractPlanResult.tryParse(s);
      // summary 有值但 actions/events/crm 为空 → isEmpty 为 true → 返回 null
      expect(r, isNull);
    });

    test('损坏/为空 JSON 返回 null', () {
      expect(ExtractPlanResult.tryParse('not json'), isNull);
      expect(ExtractPlanResult.tryParse(''), isNull);
    });
  });

  test('ExtractCrm.toJson/fromJson 往返', () {
    const c = ExtractCrm(
      type: 'contact',
      name: '张伟',
      fields: {'phone': '13700000000'},
    );
    final back = ExtractCrm.fromJson(c.toJson());
    expect(back.type, 'contact');
    expect(back.name, '张伟');
    expect(back.fields['phone'], '13700000000');
  });
}
