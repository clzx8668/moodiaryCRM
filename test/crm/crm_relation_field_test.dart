import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/widgets/crm_relation_search_field.dart';

void main() {
  testWidgets('新建失焦自动创建并关联（回归：创建模式与提交中分离）', (tester) async {
    String? created;
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CrmRelationSearchField(
            label: '联系人',
            typeLabel: '联系人',
            currentText: '',
            candidates: const [],
            recordLabel: (r) => r.toString(),
            recordId: (r) => r.toString(),
            onSelect: (id) async => selected = id,
            onCreate: (name) async {
              created = name;
              return 'new-1';
            },
          ),
        ),
      ),
    );

    // 点击字段展开搜索
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    // 无结果 → 点「新建联系人」
    await tester.tap(find.textContaining('新建联系人'));
    await tester.pumpAndSettle();

    // 输入名称后失焦 → 自动创建并关联
    await tester.enterText(find.byType(TextField).last, '王五');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(created, '王五');
    expect(selected, 'new-1');
    // 回到显示态：展示新建的名称
    expect(find.text('王五'), findsOneWidget);
  });

  testWidgets('选择已有记录即关联并回显', (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CrmRelationSearchField(
            label: '客户',
            typeLabel: '客户',
            currentText: '',
            candidates: const ['Acme 科技'],
            recordLabel: (r) => r.toString(),
            recordId: (r) => 'id-${r.toString()}',
            onSelect: (id) async => selected = id,
            onCreate: null,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme 科技'));
    await tester.pumpAndSettle();

    expect(selected, 'id-Acme 科技');
    expect(find.text('Acme 科技'), findsOneWidget);
  });
}
