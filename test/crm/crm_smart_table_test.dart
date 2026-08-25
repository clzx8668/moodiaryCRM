import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/crm/widgets/crm_smart_table.dart';

void main() {
  List<CrmEntityCache> buildItems() => [
    for (final name in ['Acme 科技', 'Notion 中国'])
      CrmEntityCache()
        ..id = 'id-$name'
        ..twentyId = 'twenty-$name'
        ..entityType = 'account'
        ..name = name
        ..setData({'name': name, 'phone': '10086'}),
  ];

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: SizedBox(width: 900, height: 500, child: child)));

  testWidgets('复选框固定首列：表头全选复选框 + 行内复选框，无三条杠菜单图标', (tester) async {
    await tester.pumpWidget(
      wrap(
        CrmSmartTable(
          items: buildItems(),
          fields: const ['name', 'phone'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 表头三态全选 + 两行复选框（自绘图标）
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsNWidgets(3));
    // 列标题无「三条杠」菜单/调整图标
    expect(find.byIcon(Icons.dehaze), findsNothing);
  });

  testWidgets('标题行右键：弹出列菜单，含升序/降序', (tester) async {
    await tester.pumpWidget(
      wrap(
        CrmSmartTable(
          items: buildItems(),
          fields: const ['name', 'phone'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 右键「名称」列标题（复选框列 36px 之后）
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.addPointer(location: const Offset(160, 20));
    await gesture.down(const Offset(160, 20));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('升序'), findsOneWidget);
    expect(find.text('降序'), findsOneWidget);

    // 选择「降序」不抛异常
    await tester.tap(find.text('降序'));
    await tester.pumpAndSettle();
  });

  testWidgets('表头全选复选框：点击即全选/再点取消全选', (tester) async {
    Set<String> selected = {};
    await tester.pumpWidget(
      wrap(
        CrmSmartTable(
          items: buildItems(),
          fields: const ['name'],
          selectedIds: selected,
          onSelectionChanged: (next) => selected = next,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 点表头全选复选框（表头自绘 overlay 在 Stack 最上层，取最后一个图标）
    await tester.tap(find.byIcon(Icons.check_box_outline_blank_rounded).last);
    await tester.pumpAndSettle();
    expect(selected, hasLength(2));

    // 父级用新选中集重建（真实应用由表格页 setState 驱动）
    await tester.pumpWidget(
      wrap(
        CrmSmartTable(
          items: buildItems(),
          fields: const ['name'],
          selectedIds: selected,
          onSelectionChanged: (next) => selected = next,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_box_rounded).last);
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
  });

  testWidgets('报价/发票等短首列：复选框仍与首列融合，不被缩放挤压', (tester) async {
    final items = [
      for (final no in ['QT-20260825-001', 'QT-20260825-002'])
        CrmEntityCache()
          ..id = 'id-$no'
          ..twentyId = 'twenty-$no'
          ..entityType = 'quote'
          ..name = no
          ..setData({'quoteNo': no, 'status': 'draft'}),
    ];
    await tester.pumpWidget(
      wrap(
        CrmSmartTable(
          items: items,
          fields: const ['quoteNo', 'status'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 表头全选 + 两行复选框均融合在首列（而非独立列）
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsNWidgets(3));
  });
}
