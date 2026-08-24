import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/crm_record_detail_shell.dart';
import 'package:moodiary/features/crm/local/crm_entity_loader.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/features/crm/widgets/crm_record_inline_fields.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;
  late CrmLocalRepository repo;

  setUp(() {
    db = openTestDb();
    repo = CrmLocalRepository(db);
  });

  tearDown(() => closeTestDb(db));

  testWidgets('关联记录就地展开：加载字段并原位编辑失焦保存', (tester) async {
    final account = await repo.createAccount(
      LocalAccount(id: '', name: 'Acme 科技', industry: '软件'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CrmRecordInlineFields(
            objectType: 'account',
            recordId: account.id,
            fields: kBaseObjectFields['account']!,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 标签字段（名称）与只读时间不重复展示；普通字段可编辑
    expect(find.text('名称'), findsNothing);
    expect(find.text('行业'), findsOneWidget);
    expect(find.text('软件'), findsOneWidget);

    // 点击行业值 → 输入 → 失焦自动保存并回显
    await tester.tap(find.text('软件'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '金融');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect((await repo.getAccount(account.id))?.industry, '金融');
    expect(find.text('金融'), findsOneWidget);
  });

  testWidgets('客户详情：关联区块内联系人支持就地展开编辑', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final account = await repo.createAccount(
      LocalAccount(id: '', name: 'Acme 科技', industry: '软件'),
    );
    await repo.createContact(
      LocalContact(id: '', name: '张三', accountId: account.id, title: '销售'),
    );
    final cache = await loadCrmEntityCache(type: 'account', id: account.id);
    expect(cache, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CrmRecordDetailShell(
            objectType: 'account',
            item: cache!,
            fields: kBaseObjectFields['account']!,
            isRoot: true,
            isMobile: true,
            onClose: () {},
            onChanged: () {},
            onDelete: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 关联区块：联系人（主关联）独立成块可见（大视口）
    expect(find.text('联系人（1）'), findsOneWidget);
    expect(find.text('张三'), findsWidgets);

    // 点展开图标 → 就地编辑器出现
    await tester.tap(find.byIcon(Icons.expand_more_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('编辑联系人'), findsOneWidget);
    expect(find.text('职位'), findsOneWidget);

    // 就地编辑职位 → 失焦保存
    await tester.tap(find.text('销售'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '总监');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final contacts = await repo.listContacts();
    expect(contacts, hasLength(1));
    expect(contacts.first.title, '总监');
  });

  testWidgets('子侧关联非空：点击关联值直接打开关联详情（Twenty RecordChip 交互）', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final account = await repo.createAccount(
      LocalAccount(id: '', name: 'Acme 科技'),
    );
    final contact = await repo.createContact(
      LocalContact(id: '', name: '张三', accountId: account.id),
    );
    final cache = await loadCrmEntityCache(type: 'contact', id: contact.id);
    expect(cache, isNotNull);

    String? openedType;
    String? openedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CrmRecordDetailShell(
            objectType: 'contact',
            item: cache!,
            fields: kBaseObjectFields['contact']!,
            isRoot: true,
            isMobile: true,
            onClose: () {},
            onChanged: () {},
            onDelete: () {},
            onOpenRelated: (type, id) {
              openedType = type;
              openedId = id;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 客户（主关联）区块非空：点值 → 打开关联详情，而非进入选择列表
    expect(find.text('Acme 科技'), findsOneWidget);
    await tester.tap(find.text('Acme 科技'));
    await tester.pumpAndSettle();
    expect(openedType, 'account');
    expect(openedId, account.id);
  });
}
