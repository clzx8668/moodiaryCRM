import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/crm_record_detail_shell.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDb());
  tearDown(() => closeTestDb(db));

  CrmEntityCache buildAccount() => CrmEntityCache()
    ..twentyId = 'acc-1'
    ..entityType = 'account'
    ..name = 'Acme 科技'
    ..setData({'name': 'Acme 科技', 'industry': '软件'});

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('桌面右侧栏：根详情页 ❌ + 标题行 + 主页/任务/笔记/文件四 Tab（Home 合并）', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        CrmRecordDetailShell(
          objectType: 'account',
          item: buildAccount(),
          fields: kBaseObjectFields['account']!,
          isRoot: true,
          isMobile: false,
          onClose: () {},
          onChanged: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 根详情页：❌ 关闭；无 ← 返回
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    // 标题行显示记录名称
    expect(find.text('Acme 科技'), findsWidgets);
    // 右抽屉合并：主页(Home) + 任务/笔记/文件；无独立「字段/时间线」Tab
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.byIcon(Icons.list_alt_rounded), findsNothing);
    expect(find.byIcon(Icons.timeline_rounded), findsNothing);
  });

  testWidgets('移动整页：子详情页 ← 返回 + 字段/时间线/任务/笔记/文件五 Tab（不合并）', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        CrmRecordDetailShell(
          objectType: 'account',
          item: buildAccount(),
          fields: kBaseObjectFields['account']!,
          isRoot: false,
          isMobile: true,
          onClose: () {},
          onChanged: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 子详情页：← 返回；无 ❌
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    // 移动端五 Tab
    expect(find.byIcon(Icons.list_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.timeline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsNothing);
  });

  testWidgets('切换 Tab：主页 → 文件，内容区切换为附件卡片', (tester) async {
    await tester.pumpWidget(
      wrap(
        CrmRecordDetailShell(
          objectType: 'account',
          item: buildAccount(),
          fields: kBaseObjectFields['account']!,
          isRoot: true,
          isMobile: true,
          onClose: () {},
          onChanged: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 初始在「字段」Tab：无附件卡片
    expect(find.textContaining('附件（'), findsNothing);

    // 切到「文件」Tab
    await tester.tap(find.text('文件'));
    await tester.pumpAndSettle();
    expect(find.textContaining('附件（'), findsOneWidget);
  });

  testWidgets('子详情页：显示父页面关联上下文', (tester) async {
    await tester.pumpWidget(
      wrap(
        CrmRecordDetailShell(
          objectType: 'contact',
          item: CrmEntityCache()
            ..twentyId = 'c-1'
            ..entityType = 'contact'
            ..name = '张三',
          fields: kBaseObjectFields['contact']!,
          isRoot: false,
          isMobile: true,
          parentLabel: '来自 客户 · Acme 科技',
          onClose: () {},
          onChanged: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('来自 客户 · Acme 科技'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('桌面整页：左列 Summary+Fields，右侧 Timeline/Tasks/Notes/Files 四 Tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        CrmRecordDetailShell(
          objectType: 'account',
          item: buildAccount(),
          fields: kBaseObjectFields['account']!,
          isRoot: true,
          isFullPage: true,
          isMobile: false,
          onClose: () {},
          onChanged: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 无合并 Home、无独立「字段」Tab；右侧为时间线/任务/笔记/文件
    expect(find.byIcon(Icons.home_rounded), findsNothing);
    expect(find.byIcon(Icons.list_alt_rounded), findsNothing);
    expect(find.byIcon(Icons.timeline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    // 左列字段卡（核心信息区块）仍渲染；主关联「联系人」区块必显
    expect(find.textContaining('核心信息（'), findsOneWidget);
    expect(find.text('联系人（0）'), findsOneWidget);
  });

  testWidgets('主页核心信息：默认只显示核心字段，可展开全部', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        CrmRecordDetailShell(
          objectType: 'account',
          item: buildAccount(),
          fields: kBaseObjectFields['account']!,
          isRoot: true,
          isMobile: true,
          onClose: () {},
          onChanged: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 默认 7/11 核心字段；非核心字段（地址）隐藏
    expect(find.text('核心信息（7/11）'), findsOneWidget);
    expect(find.text('客户类型'), findsOneWidget);
    expect(find.text('行业'), findsOneWidget);
    expect(find.text('地址'), findsNothing);

    // 展开全部 → 全部 11 个字段可见
    await tester.tap(find.text('展开全部'));
    await tester.pumpAndSettle();
    expect(find.text('核心信息（11/11）'), findsOneWidget);
    expect(find.text('地址'), findsOneWidget);
  });

  testWidgets('主页「添加区块」下拉：可把暂无内容的关联类型固定为新区块', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        CrmRecordDetailShell(
          objectType: 'account',
          item: buildAccount(),
          fields: kBaseObjectFields['account']!,
          isRoot: true,
          isMobile: true,
          onClose: () {},
          onChanged: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 无内容关联（报价）默认不显示；主关联「联系人」必显
    expect(find.text('报价（0）'), findsNothing);
    expect(find.text('联系人（0）'), findsOneWidget);

    // 通过「添加区块」固定显示报价区块
    await tester.tap(find.text('添加区块'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加报价区块'));
    await tester.pumpAndSettle();
    expect(find.text('报价（0）'), findsOneWidget);
  });
}
