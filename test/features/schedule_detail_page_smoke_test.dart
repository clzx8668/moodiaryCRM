import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/schedule/views/schedule_detail_page.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDb());
  tearDown(() {
    Get.reset();
    closeTestDb(db);
  });

  testWidgets('日程详情页新建态渲染不异常', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ScheduleDetailPage())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('新建日程'), findsOneWidget);
    expect(find.text('无固定日期（浮动收件箱）'), findsOneWidget);
  });
}
