import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/features/schedule/views/quick_add_schedule_sheet.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDb());
  tearDown(() => closeTestDb(db));

  Future<void> openSheet(WidgetTester tester, DateTime? initial) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showQuickAddScheduleSheet(context, initial: initial),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  List<ChoiceChip> selectedChips(WidgetTester tester) => tester
      .widgetList<ChoiceChip>(find.byType(ChoiceChip))
      .where((c) => c.selected)
      .toList();

  testWidgets('默认日期跟随传入的选中日，日期芯片有明确选中态', (tester) async {
    final target = DateTime(2030, 3, 5); // 既不是今天也不是明天
    await openSheet(tester, target);

    // 第三颗芯片显示传入日期，且只有它能是选中态
    expect(find.text('3月5日'), findsOneWidget);
    final selected = selectedChips(tester);
    expect(selected, hasLength(1));
    expect(
      ((selected.first.label as Text).data),
      '3月5日',
      reason: '应高亮传入的日期，而不是无差别三颗按钮',
    );

    await tester.enterText(find.byType(TextField).first, '走查用例日程');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final created = await ScheduleRepository().listActive();
    expect(created, hasLength(1));
    expect(created.first.startTime, DateTime(2030, 3, 5, 9));
  });

  testWidgets('今天/明天芯片互斥选中', (tester) async {
    await openSheet(tester, DateTime.now());
    expect((selectedChips(tester).first.label as Text).data, '今天');

    await tester.tap(find.text('明天'));
    await tester.pumpAndSettle();
    expect((selectedChips(tester).first.label as Text).data, '明天');
  });
}
