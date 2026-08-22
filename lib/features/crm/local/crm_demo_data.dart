import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';

/// CRM 演示数据生成器：为全部表生成 5–10 条真实关联数据，用于功能验证。
/// 仅追加，不删除现有数据。
class CrmDemoData {
  static Future<Map<String, int>> seed(CrmLocalRepository repo) async {
    final counts = <String, int>{};

    // ---- 产品分类 / 产品 ----
    final sw = await repo.createProductCategory(
      LocalProductCategory(id: '', name: '软件服务'),
    );
    final hw = await repo.createProductCategory(
      LocalProductCategory(id: '', name: '硬件设备'),
    );
    final cs = await repo.createProductCategory(
      LocalProductCategory(id: '', name: '咨询服务'),
    );
    final products = <LocalProduct>[];
    for (final p in const [
      ('CRM 基础版', 'CRM-BASIC', 'product', '套', 999.0),
      ('CRM 专业版', 'CRM-PRO', 'product', '套', 2999.0),
      ('实施服务', 'IMPL-SVC', 'service', '人天', 2000.0),
      ('年度维保', 'MAINT-1Y', 'service', '年', 1500.0),
      ('企业服务器', 'SRV-E200', 'product', '台', 45000.0),
      ('核心交换机', 'SW-C8500', 'product', '台', 12000.0),
      ('流程咨询', 'CONS-PRC', 'service', '次', 30000.0),
      ('交付培训', 'TRN-DLV', 'service', '场', 8000.0),
    ]) {
      products.add(
        await repo.createProduct(
          LocalProduct(
            id: '',
            categoryId: p.$3 == 'product'
                ? (p.$2.startsWith('CRM') || p.$2.startsWith('IMPL') ||
                          p.$2.startsWith('MAINT') || p.$2.startsWith('TRN')
                      ? sw.id
                      : hw.id)
                : (p.$2 == 'CONS-PRC' ? cs.id : sw.id),
            name: p.$1,
            sku: p.$2,
            type: p.$3,
            unit: p.$4,
            price: p.$5,
            warrantyMonths: p.$3 == 'product' ? 12 : 0,
          ),
        ),
      );
    }
    counts['product'] = products.length;
    counts['productCategory'] = 3;

    // ---- 客户 ----
    final accounts = <LocalAccount>[];
    for (final a in const [
      ('Notion 科技', 'company', '软件', 'Notion Tech', '010-88880001'),
      ('星辰信息技术', 'company', '软件', 'Stellar Info', '021-66660001'),
      ('华信能源集团', 'company', '能源', 'Huaxin Energy', '0755-33330001'),
      ('远大智能制造', 'company', '制造', 'Yuanda Mfg', '0512-22220001'),
      ('清源咨询', 'org', '咨询', 'Qingyuan Consult', '010-77770001'),
      ('王明', 'person', '个人', '', '13800001111'),
    ]) {
      accounts.add(
        await repo.createAccount(
          LocalAccount(
            id: '',
            name: a.$1,
            type: a.$2,
            industry: a.$3,
            website: a.$4,
            phone: a.$5,
            level: a.$2 == 'person' ? 'potential' : 'normal',
          ),
        ),
      );
    }
    counts['account'] = accounts.length;

    // ---- 联系人 ----
    final contacts = <LocalContact>[];
    for (final c in const [
      (0, '张伟', '销售总监', true, true),
      (0, '李娜', '采购经理', false, false),
      (1, '刘洋', 'CTO', true, true),
      (2, '陈静', '信息中心主任', true, true),
      (3, '赵强', '设备科长', true, true),
      (4, '孙丽', '合伙人', true, true),
      (5, '周杰', '', true, false),
      (1, '吴敏', '财务经理', false, false),
    ]) {
      contacts.add(
        await repo.createContact(
          LocalContact(
            id: '',
            accountId: accounts[c.$1].id,
            name: c.$2,
            title: c.$3,
            phone: '139${(c.$1 + 100000000).toString().substring(1)}',
            email: '${c.$2}@demo.com',
            isPrimary: c.$4,
            isDecisionMaker: c.$5,
          ),
        ),
      );
    }
    counts['contact'] = contacts.length;

    // ---- 机会 ----
    final opportunities = <LocalOpportunity>[];
    for (final o in const [
      (0, 'CRM 专业版采购', '方案报价', 60, 89900.0, 'website'),
      (1, '一体化 OA+CRM', '商务谈判', 75, 260000.0, 'referral'),
      (2, '能源集团数字化', '需求确认', 40, 1500000.0, 'ad'),
      (3, '智能工厂 MES 一期', '已联系', 25, 800000.0, 'exhibition'),
      (4, '流程咨询项目', '新线索', 10, 120000.0, 'referral'),
      (5, '个人版订阅', '赢单', 100, 999.0, 'website'),
      (0, '服务器扩容', '输单', 0, 90000.0, 'other'),
    ]) {
      opportunities.add(
        await repo.createOpportunity(
          LocalOpportunity(
            id: '',
            accountId: accounts[o.$1].id,
            contactId: contacts[o.$1].id,
            name: o.$2,
            stage: o.$3,
            probability: o.$4,
            amount: o.$5,
            source: o.$6,
            expectedCloseDate: DateTime.now().add(Duration(days: 10 + o.$1 * 5)),
          ),
        ),
      );
    }
    counts['opportunity'] = opportunities.length;

    // ---- 报价单 / 明细 ----
    final quotes = <LocalQuote>[];
    for (var i = 0; i < 6; i++) {
      final opp = opportunities[i];
      final status = const ['sent', 'accepted', 'draft', 'rejected', 'accepted', 'expired'][i];
      quotes.add(
        await repo.createQuote(
          LocalQuote(
            id: '',
            opportunityId: opp.id,
            accountId: opp.accountId,
            contactId: opp.contactId,
            status: status,
            validUntil: DateTime.now().add(const Duration(days: 15)),
          ),
        ),
      );
      final q = quotes.last;
      final product = products[i % products.length];
      final product2 = products[(i + 3) % products.length];
      await repo.addQuoteItem(
        LocalQuoteItem(
          id: '',
          quoteId: q.id,
          productId: product.id,
          productName: product.name,
          quantity: (i % 3) + 1,
          unitPrice: product.price,
          discount: i % 2 == 0 ? 0.95 : 1,
        ),
      );
      await repo.addQuoteItem(
        LocalQuoteItem(
          id: '',
          quoteId: q.id,
          productId: product2.id,
          productName: product2.name,
          quantity: 2,
          unitPrice: product2.price,
        ),
      );
    }
    counts['quote'] = quotes.length;
    counts['quoteItem'] = quotes.length * 2;

    // ---- 合同（含报价转合同） ----
    final contracts = <LocalContract>[];
    // 两条 accepted 报价转合同（验证流程）
    for (var i = 0; i < 2; i++) {
      final idx = const [1, 4][i];
      contracts.add(await repo.quoteToContract(quotes[idx].id));
    }
    // 其余直接建合同
    for (var i = 0; i < 4; i++) {
      final opp = opportunities[i];
      contracts.add(
        await repo.createContract(
          LocalContract(
            id: '',
            name: '${opp.name}合同',
            accountId: opp.accountId,
            contactId: opp.contactId,
            opportunityId: opp.id,
            status: const ['active', 'active', 'draft', 'completed'][i],
            totalAmount: opp.amount,
            signDate: DateTime.now().subtract(Duration(days: 20 + i)),
            startDate: DateTime.now().subtract(Duration(days: 15 + i)),
            endDate: DateTime.now().add(Duration(days: 300 + i * 30)),
          ),
        ),
      );
    }
    // 给未转合同的合同补明细
    for (var i = 2; i < 6; i++) {
      final contract = contracts[i];
      final product = products[i % products.length];
      await repo.addContractItem(
        LocalContractItem(
          id: '',
          contractId: contract.id,
          productId: product.id,
          productName: product.name,
          quantity: i.toDouble(),
          unitPrice: product.price,
          warrantyMonths: product.warrantyMonths,
        ),
      );
    }
    counts['contract'] = contracts.length;
    counts['contractItem'] = 2 * 2 + 4; // 转合同2条各2项 + 手动4条各1项

    // ---- 回款计划 / 回款 / 发票 ----
    const planNames = ['首付款', '进度款', '验收款', '尾款'];
    final paymentPlans = <LocalPaymentPlan>[];
    for (var i = 0; i < 6; i++) {
      final contract = contracts[i % contracts.length];
      paymentPlans.add(
        await repo.createPaymentPlan(
          LocalPaymentPlan(
            id: '',
            contractId: contract.id,
            planName: planNames[i % planNames.length],
            planAmount: 10000 + i * 5000,
            planDate: DateTime.now().add(Duration(days: i * 6 - 3)),
          ),
        ),
      );
    }
    final payments = <LocalPayment>[];
    for (var i = 0; i < 6; i++) {
      final contract = contracts[i % contracts.length];
      final plan = paymentPlans[i];
      payments.add(
        await repo.createPayment(
          LocalPayment(
            id: '',
            contractId: contract.id,
            planId: plan.id,
            amount: i % 2 == 0 ? plan.planAmount : plan.planAmount / 2,
            method: const ['transfer', 'wechat', 'transfer', 'alipay', 'check', 'transfer'][i],
            paymentDate: DateTime.now().subtract(Duration(days: i)),
          ),
        ),
      );
    }
    final invoices = <LocalInvoice>[];
    for (var i = 0; i < 6; i++) {
      final contract = contracts[i % contracts.length];
      invoices.add(
        await repo.createInvoice(
          LocalInvoice(
            id: '',
            contractId: contract.id,
            invoiceNo: 'INV-2026-${(1000 + i)}',
            type: i % 2 == 0 ? 'vat_special' : 'electronic',
            amount: 5000 + i * 3000,
            status: const ['issued', 'delivered', 'pending', 'issued', 'void', 'delivered'][i],
            receiverName: contacts[i % contacts.length].name,
            issueDate: DateTime.now().subtract(Duration(days: i * 2)),
          ),
        ),
      );
    }
    counts['paymentPlan'] = paymentPlans.length;
    counts['payment'] = payments.length;
    counts['invoice'] = invoices.length;

    // ---- 质保 / 售后 ----
    for (var i = 0; i < 6; i++) {
      final contract = contracts[i % contracts.length];
      final product = products[(i + 1) % products.length];
      await repo.createWarranty(
        LocalWarranty(
          id: '',
          contractId: contract.id,
          productId: product.id,
          serialNo: 'SN-DEMO-${1000 + i}',
          startDate: DateTime.now().subtract(Duration(days: 100 - i * 10)),
          endDate: DateTime.now().add(Duration(days: 20 + i * 40)),
        ),
      );
    }
    for (var i = 0; i < 6; i++) {
      final account = accounts[i % accounts.length];
      final contract = contracts[i % contracts.length];
      await repo.createAfterSales(
        LocalAfterSales(
          id: '',
          accountId: account.id,
          contractId: contract.id,
          contactId: contacts[i % contacts.length].id,
          type: const ['repair', 'install', 'consult', 'complaint', 'other', 'repair'][i],
          priority: const ['high', 'medium', 'low', 'urgent', 'medium', 'high'][i],
          status: const ['open', 'inProgress', 'resolved', 'closed', 'open', 'waitingCustomer'][i],
          subject: '演示工单-${1000 + i}',
          description: '客户反馈：${contract.name} 相关问题的演示描述。',
        ),
      );
    }
    counts['warranty'] = 6;
    counts['afterSales'] = 6;

    // ---- 自定义对象示例：拜访记录 ----
    final visitDef = await repo.createCustomObject(
      LocalCustomObject(
        id: 'visits',
        labelSingular: '拜访',
        labelPlural: '拜访记录',
        icon: 'handshake',
        fields: const [
          CrmFieldDef(name: 'accountName', label: '客户', type: 'text'),
          CrmFieldDef(name: 'visitDate', label: '拜访日期', type: 'date'),
          CrmFieldDef(name: 'content', label: '内容', type: 'textarea'),
          CrmFieldDef(name: 'result', label: '结果', type: 'select', options: [
            '有效沟通',
            '待跟进',
            '已签约',
            '暂缓',
          ]),
        ],
      ),
    );
    var visitCount = 0;
    for (var i = 0; i < 6; i++) {
      final account = accounts[i % accounts.length];
      await repo.createCustomRecord(
        LocalCustomRecord(
          id: '',
          objectId: visitDef.id,
          label: '拜访 ${account.name}',
          data: {
            'accountName': account.name,
            'visitDate': DateTime.now()
                .subtract(Duration(days: i * 3))
                .toIso8601String(),
            'content': '与 ${contacts[i % contacts.length].name} 就合作事项深入沟通。',
            'result': const ['有效沟通', '待跟进', '已签约', '暂缓'][i % 4],
          },
        ),
      );
      visitCount++;
    }
    counts['customObject'] = 1;
    counts['customRecord'] = visitCount;

    return counts;
  }
}
