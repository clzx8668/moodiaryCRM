import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/extract/extract_plan_service.dart';

void main() {
  group('ExtractPlanService.parseBatchResponse（一次调用多条笔记）', () {
    test('按 id 逐条对应解析', () {
      const raw = '''
{
  "note-a": {"actions":[{"title":"交报告","dueAt":"明天","priority":"高","note":""}],
             "events":[],"crm":[],"summary":"交报告"},
  "note-b": {"actions":[],"events":[{"title":"开会","start":"下午3点","end":null,
             "allDay":false,"remind":null}],"crm":[],"summary":""}
}''';
      final r = ExtractPlanService.parseBatchResponse(raw, ['note-a', 'note-b']);
      expect(r.keys.toSet(), {'note-a', 'note-b'});
      expect(r['note-a']!.actions.first.title, '交报告');
      expect(r['note-b']!.events.first.title, '开会');
    });

    test('容忍 ```json 包裹与多余前后文字', () {
      const raw = '''
好的，结果如下：
```json
{"n1":{"actions":[{"title":"买牛奶","dueAt":null,"priority":"","note":""}],
       "events":[],"crm":[],"summary":""}}
```
以上。
''';
      final r = ExtractPlanService.parseBatchResponse(raw, ['n1']);
      expect(r['n1']!.actions.first.title, '买牛奶');
    });

    test('只接受我们发出去的 id（模型编造的 id 被丢弃）', () {
      const raw = '{"n1":{"actions":[],"events":[],"crm":[],"summary":""},'
          '"богus":{"actions":[{"title":"假","dueAt":null,"priority":"","note":""}],'
          '"events":[],"crm":[],"summary":""}}';
      final r = ExtractPlanService.parseBatchResponse(raw, ['n1']);
      expect(r.keys, ['n1']);
    });

    test('缺少某条 id 时不影响其它条（逐条对应）', () {
      const raw = '{"n1":{"actions":[],"events":[],"crm":[],"summary":"只有这条"}}';
      final r = ExtractPlanService.parseBatchResponse(raw, ['n1', 'n2']);
      expect(r.containsKey('n1'), isTrue);
      expect(r.containsKey('n2'), isFalse);
    });

    test('非法 JSON / 空内容安全返回', () {
      expect(ExtractPlanService.parseBatchResponse('not json', ['n1']), isEmpty);
      expect(ExtractPlanService.parseBatchResponse('', ['n1']), isEmpty);
      expect(ExtractPlanService.parseBatchResponse('{}', ['n1']), isEmpty);
    });

    test('value 不是对象时跳过该条', () {
      const raw = '{"n1":"字符串不是结果","n2":{"actions":[],"events":[],"crm":[],"summary":"ok"}}';
      final r = ExtractPlanService.parseBatchResponse(raw, ['n1', 'n2']);
      expect(r.containsKey('n1'), isFalse);
      expect(r['n2']!.summary, 'ok');
    });
  });
}
