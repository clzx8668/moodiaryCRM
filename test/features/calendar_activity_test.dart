import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/activity/calendar_activity.dart';

Diary makeDiary({
  required String id,
  required DateTime time,
  required String text,
  double mood = 0.5,
}) {
  return Diary()
    ..id = id
    ..contentText = text
    ..time = time
    ..mood = mood
    ..type = 'text'
    ..show = true;
}

void main() {
  test('空数据返回空映射', () {
    expect(CalendarActivity.calculate([], {}), isEmpty);
  });

  test('多日记按日聚合，字数与 Block 影响分数', () {
    final d1 = DateTime(2026, 8, 19);
    final d2 = DateTime(2026, 8, 20);
    final diaries = [
      makeDiary(id: 'a', time: d1, text: 'x' * 100, mood: 0.8),
      makeDiary(id: 'b', time: d1, text: 'y' * 100, mood: 0.2),
      makeDiary(id: 'c', time: d2, text: 'z' * 10, mood: 0.5),
    ];
    final blockCounts = {'a': 5, 'b': 3, 'c': 0};

    final activity = CalendarActivity.calculate(diaries, blockCounts);

    expect(activity.keys, containsAll([d1, d2]));
    // 8/19 字数多、Block 多，分数应高于 8/20
    expect(activity[d1]!, greaterThan(activity[d2]!));
    // 归一化后最大值应为 1.0
    expect(activity.values.reduce((a, b) => a > b ? a : b), 1.0);
  });

  test('单日多篇日记合并心情平均', () {
    final day = DateTime(2026, 8, 19);
    final diaries = [
      makeDiary(id: 'a', time: day, text: 't', mood: 1.0),
      makeDiary(id: 'b', time: day, text: 't', mood: 0.0),
    ];
    final activity = CalendarActivity.calculate(diaries, {});
    // 心情平均 0.5，字数很少，Block 为 0
    final score = activity[day]!;
    expect(score, greaterThan(0.0));
    expect(score, lessThanOrEqualTo(1.0));
  });
}
