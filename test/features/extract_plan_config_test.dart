import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/extract/extract_plan_config.dart';

void main() {
  test('默认全部开启', () {
    final c = ExtractPlanConfig();
    expect(c.todo, isTrue);
    expect(c.schedule, isTrue);
    expect(c.crm, isTrue);
    expect(c.summary, isTrue);
  });

  test('toJson/fromJson 往返一致', () {
    final c = ExtractPlanConfig()
      ..todo = false
      ..schedule = true
      ..crm = false
      ..summary = true;
    final back = ExtractPlanConfig.fromJson(c.toJson());
    expect(back.todo, isFalse);
    expect(back.schedule, isTrue);
    expect(back.crm, isFalse);
    expect(back.summary, isTrue);
  });

  test('fromJson 缺省字段回退 true', () {
    final c = ExtractPlanConfig.fromJson({'crm': false});
    expect(c.crm, isFalse);
    expect(c.todo, isTrue);
  });
}
