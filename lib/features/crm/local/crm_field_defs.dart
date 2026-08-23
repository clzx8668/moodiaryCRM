library;

import 'crm_models.dart';

/// 本地 CRM 字段定义（基础对象默认展示字段，参照成熟 CRM 视图）。

class LocalObjectField {
  final String name;
  final String label;
  final String type; // text / number / date / select / textarea / relation / currency
  final List<String> options;

  const LocalObjectField(
    this.name,
    this.label, {
    this.type = 'text',
    this.options = const [],
  });
}

/// 常用币种与系统默认币种
const List<String> kCurrencies = ['CNY', 'USD', 'EUR', 'GBP', 'HKD', 'JPY'];
const String kDefaultCurrency = 'CNY';

/// 日期输入归一化：支持 yyyy-MM-dd / yyyy/M/d / yyyy年M月d日 / yyyy.M.d，
/// 统一为 yyyy-MM-dd；无法识别返回 null。
String? normalizeDateInput(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final m = RegExp(
    r'^(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})日?$',
  ).firstMatch(text);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return '$y-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

/// 各基础对象的标签标识字段
const Map<String, String> kLocalLabelFields = {
  'account': 'name',
  'contact': 'name',
  'opportunity': 'name',
  'contract': 'name',
  'product': 'name',
  'quote': 'quoteNo',
  'paymentPlan': 'planName',
  'payment': 'paymentDate',
  'invoice': 'invoiceNo',
  'warranty': 'serialNo',
  'afterSales': 'ticketNo',
  'activity': 'subject',
  'reminder': 'title',
};

/// 商机阶段（doc 枚举键，先以中文标签存储展示；S6 看板再做键值化）
const List<String> kOpportunityStages = [
  '新线索',
  '已联系',
  '需求确认',
  '方案报价',
  '商务谈判',
  '赢单',
  '输单',
  '放弃',
];

const Map<String, List<LocalObjectField>> kBaseObjectFields = {
  'account': [
    LocalObjectField('name', '名称'),
    LocalObjectField('contact', '联系人', type: 'relation'),
    LocalObjectField('opportunity', '商机', type: 'relation'),
    LocalObjectField('contract', '合同', type: 'relation'),
    LocalObjectField('quote', '报价', type: 'relation'),
    LocalObjectField('type', '客户类型', type: 'select', options: [
      'company',
      'person',
      'org',
    ]),
    LocalObjectField('industry', '行业'),
    LocalObjectField('level', '等级', type: 'select', options: [
      'vip',
      'normal',
      'potential',
    ]),
    LocalObjectField('source', '来源'),
    LocalObjectField('phone', '电话'),
    LocalObjectField('email', '邮箱'),
    LocalObjectField('address', '地址'),
    LocalObjectField('website', '网址'),
    LocalObjectField('creditCode', '统一信用代码'),
    LocalObjectField('status', '状态', type: 'select', options: [
      'active',
      'inactive',
      'blacklist',
    ]),
    LocalObjectField('note', '备注', type: 'textarea'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
  'contact': [
    LocalObjectField('name', '姓名'),
    LocalObjectField('account', '所属客户', type: 'relation'),
    LocalObjectField('title', '职位'),
    LocalObjectField('department', '部门'),
    LocalObjectField('phone', '手机'),
    LocalObjectField('email', '邮箱'),
    LocalObjectField('wechat', '微信'),
    LocalObjectField('isPrimary', '主联系人', type: 'select', options: [
      'true',
      'false',
    ]),
    LocalObjectField('isDecisionMaker', '决策人', type: 'select', options: [
      'true',
      'false',
    ]),
    LocalObjectField('note', '备注', type: 'textarea'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
  'opportunity': [
    LocalObjectField('name', '名称'),
    LocalObjectField('account', '客户', type: 'relation'),
    LocalObjectField('contact', '联系人', type: 'relation'),
    LocalObjectField('stage', '阶段', type: 'select', options: kOpportunityStages),
    LocalObjectField('probability', '成交概率(%)', type: 'number'),
    LocalObjectField('amount', '预计金额', type: 'currency'),
    LocalObjectField('currency', '币种', type: 'currency'),
    LocalObjectField('source', '来源渠道'),
    LocalObjectField('leadContactName', '线索联系人'),
    LocalObjectField('leadPhone', '线索电话'),
    LocalObjectField('leadEmail', '线索邮箱'),
    LocalObjectField('expectedCloseDate', '预计成交日期', type: 'date'),
    LocalObjectField('actualCloseDate', '实际成交日期', type: 'date'),
    LocalObjectField('lossReason', '输单/放弃原因'),
    LocalObjectField('note', '备注', type: 'textarea'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
  'contract': [
    LocalObjectField('contractNo', '合同编号'),
    LocalObjectField('name', '合同名称'),
    LocalObjectField('account', '客户', type: 'relation'),
    LocalObjectField('contact', '签约联系人', type: 'relation'),
    LocalObjectField('currency', '币种', type: 'currency'),
    LocalObjectField('status', '状态', type: 'select', options: [
      'draft',
      'active',
      'completed',
      'terminated',
      'expired',
    ]),
    LocalObjectField('totalAmount', '总金额', type: 'currency'),
    LocalObjectField('paidAmount', '已回款', type: 'currency'),
    LocalObjectField('invoicedAmount', '已开票', type: 'currency'),
    LocalObjectField('signDate', '签约日期', type: 'date'),
    LocalObjectField('startDate', '开始日期', type: 'date'),
    LocalObjectField('endDate', '结束日期', type: 'date'),
    LocalObjectField('warrantyEndDate', '质保到期', type: 'date'),
    LocalObjectField('note', '备注', type: 'textarea'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
  'product': [
    LocalObjectField('name', '产品/服务名称'),
    LocalObjectField('sku', '编码'),
    LocalObjectField('currency', '币种', type: 'currency'),
    LocalObjectField('type', '类型', type: 'select', options: [
      'product',
      'service',
    ]),
    LocalObjectField('unit', '单位'),
    LocalObjectField('price', '标准单价', type: 'currency'),
    LocalObjectField('cost', '成本价', type: 'currency'),
    LocalObjectField('warrantyMonths', '质保月数', type: 'number'),
    LocalObjectField('isActive', '在售', type: 'select', options: [
      'true',
      'false',
    ]),
    LocalObjectField('note', '描述', type: 'textarea'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
  'quote': [
    LocalObjectField('quoteNo', '报价单号'),
    LocalObjectField('account', '客户', type: 'relation'),
    LocalObjectField('contact', '联系人', type: 'relation'),
    LocalObjectField('opportunity', '商机', type: 'relation'),
    LocalObjectField('currency', '币种', type: 'currency'),
    LocalObjectField('status', '状态', type: 'select', options: [
      'draft',
      'sent',
      'accepted',
      'rejected',
      'expired',
    ]),
    LocalObjectField('totalAmount', '总金额', type: 'currency'),
    LocalObjectField('discountAmount', '折扣金额', type: 'currency'),
    LocalObjectField('validUntil', '有效期至', type: 'date'),
    LocalObjectField('note', '备注', type: 'textarea'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
  'paymentPlan': [
    LocalObjectField('planName', '期次名称'),
    LocalObjectField('contract', '合同', type: 'relation'),
    LocalObjectField('planAmount', '计划金额', type: 'currency'),
    LocalObjectField('paidAmount', '已收金额', type: 'currency'),
    LocalObjectField('planDate', '计划回款日期', type: 'date'),
    LocalObjectField('status', '状态', type: 'select', options: [
      'pending',
      'partial',
      'completed',
      'overdue',
    ]),
  ],
  'payment': [
    LocalObjectField('paymentDate', '回款日期', type: 'date'),
    LocalObjectField('contract', '合同', type: 'relation'),
    LocalObjectField('plan', '回款计划', type: 'relation'),
    LocalObjectField('currency', '币种', type: 'currency'),
    LocalObjectField('amount', '金额', type: 'currency'),
    LocalObjectField('method', '方式', type: 'select', options: [
      'cash',
      'transfer',
      'check',
      'wechat',
      'alipay',
    ]),
    LocalObjectField('note', '备注', type: 'textarea'),
  ],
  'invoice': [
    LocalObjectField('invoiceNo', '发票号'),
    LocalObjectField('contract', '合同', type: 'relation'),
    LocalObjectField('currency', '币种', type: 'currency'),
    LocalObjectField('type', '类型', type: 'select', options: [
      'vat_special',
      'vat_normal',
      'electronic',
    ]),
    LocalObjectField('amount', '开票金额', type: 'currency'),
    LocalObjectField('taxRate', '税率', type: 'number'),
    LocalObjectField('issueDate', '开票日期', type: 'date'),
    LocalObjectField('status', '状态', type: 'select', options: [
      'pending',
      'issued',
      'delivered',
      'void',
    ]),
    LocalObjectField('receiverName', '收票人'),
    LocalObjectField('note', '备注', type: 'textarea'),
  ],
  'warranty': [
    LocalObjectField('serialNo', '序列号'),
    LocalObjectField('contract', '合同', type: 'relation'),
    LocalObjectField('product', '产品', type: 'relation'),
    LocalObjectField('startDate', '质保开始', type: 'date'),
    LocalObjectField('endDate', '质保到期', type: 'date'),
    LocalObjectField('status', '状态', type: 'select', options: [
      'active',
      'expired',
      'void',
    ]),
    LocalObjectField('note', '备注', type: 'textarea'),
  ],
  'afterSales': [
    LocalObjectField('ticketNo', '工单号'),
    LocalObjectField('subject', '主题'),
    LocalObjectField('account', '客户', type: 'relation'),
    LocalObjectField('contact', '联系人', type: 'relation'),
    LocalObjectField('contract', '合同', type: 'relation'),
    LocalObjectField('type', '类型', type: 'select', options: [
      'repair',
      'install',
      'consult',
      'complaint',
      'other',
    ]),
    LocalObjectField('priority', '优先级', type: 'select', options: [
      'low',
      'medium',
      'high',
      'urgent',
    ]),
    LocalObjectField('status', '状态', type: 'select', options: [
      'open',
      'inProgress',
      'waitingCustomer',
      'resolved',
      'closed',
    ]),
    LocalObjectField('description', '描述', type: 'textarea'),
    LocalObjectField('resolution', '解决方案', type: 'textarea'),
    LocalObjectField('note', '备注', type: 'textarea'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
  'activity': [
    LocalObjectField('subject', '主题'),
    LocalObjectField('type', '类型', type: 'select', options: [
      'call',
      'meeting',
      'email',
      'wechat',
      'visit',
      'task',
      'note',
    ]),
    LocalObjectField('direction', '方向', type: 'select', options: [
      'inbound',
      'outbound',
    ]),
    LocalObjectField('status', '状态', type: 'select', options: [
      'planned',
      'completed',
      'canceled',
    ]),
    LocalObjectField('scheduledAt', '计划时间', type: 'date'),
    LocalObjectField('content', '内容', type: 'textarea'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
  ],
  'reminder': [
    LocalObjectField('title', '标题'),
    LocalObjectField('type', '类型', type: 'select', options: [
      'paymentDue',
      'warrantyExpire',
      'followUp',
      'contractExpire',
      'custom',
    ]),
    LocalObjectField('remindAt', '提醒时间', type: 'date'),
    LocalObjectField('isCompleted', '已完成', type: 'select', options: [
      'true',
      'false',
    ]),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
  ],
};

/// 关系字段定义：某对象上的 relation 字段 → 候选记录类型 + 方向。
/// [currentIsParent] = true 表示当前实体是父（选中的记录挂到当前，多值）；
/// false 表示当前实体是子（当前挂到选中的记录，单值）。
class CrmRelationDef {
  final String candidateType;
  final bool currentIsParent;

  const CrmRelationDef(this.candidateType, {required this.currentIsParent});
}

const Map<String, Map<String, CrmRelationDef>> kRelationDefs = {
  'account': {
    'contact': CrmRelationDef('contact', currentIsParent: true),
    'opportunity': CrmRelationDef('opportunity', currentIsParent: true),
    'contract': CrmRelationDef('contract', currentIsParent: true),
    'quote': CrmRelationDef('quote', currentIsParent: true),
  },
  'contact': {
    'account': CrmRelationDef('account', currentIsParent: false),
  },
  'opportunity': {
    'account': CrmRelationDef('account', currentIsParent: false),
    'contact': CrmRelationDef('contact', currentIsParent: false),
  },
  'contract': {
    'account': CrmRelationDef('account', currentIsParent: false),
    'contact': CrmRelationDef('contact', currentIsParent: false),
    'opportunity': CrmRelationDef('opportunity', currentIsParent: false),
    'quote': CrmRelationDef('quote', currentIsParent: false),
  },
  'quote': {
    'account': CrmRelationDef('account', currentIsParent: false),
    'contact': CrmRelationDef('contact', currentIsParent: false),
    'opportunity': CrmRelationDef('opportunity', currentIsParent: false),
  },
  'paymentPlan': {
    'contract': CrmRelationDef('contract', currentIsParent: false),
  },
  'payment': {
    'contract': CrmRelationDef('contract', currentIsParent: false),
    'plan': CrmRelationDef('paymentPlan', currentIsParent: false),
  },
  'invoice': {
    'contract': CrmRelationDef('contract', currentIsParent: false),
  },
  'warranty': {
    'contract': CrmRelationDef('contract', currentIsParent: false),
    'product': CrmRelationDef('product', currentIsParent: false),
  },
  'afterSales': {
    'account': CrmRelationDef('account', currentIsParent: false),
    'contact': CrmRelationDef('contact', currentIsParent: false),
    'contract': CrmRelationDef('contract', currentIsParent: false),
  },
};

/// relation 字段名 → 子侧外键字段名（当前实体挂到父时写入的字段）。
String relationFieldToFk(String field) {
  switch (field) {
    case 'account':
      return 'accountId';
    case 'contact':
      return 'contactId';
    case 'opportunity':
      return 'opportunityId';
    case 'contract':
      return 'contractId';
    case 'plan':
      return 'planId';
    case 'product':
      return 'productId';
    case 'quote':
      return 'quoteId';
    default:
      return '${field}Id';
  }
}

/// 关系候选记录的展示文本（各对象的主标签）。
String crmRecordLabel(String type, Object record) {
  switch (type) {
    case 'account':
      return (record as LocalAccount).name;
    case 'contact':
      return (record as LocalContact).name;
    case 'opportunity':
      return (record as LocalOpportunity).name;
    case 'contract':
      final c = record as LocalContract;
      return c.name.isEmpty ? c.contractNo : c.name;
    case 'quote':
      final q = record as LocalQuote;
      return q.quoteNo.isEmpty ? '（未编号报价）' : q.quoteNo;
    case 'paymentPlan':
      return (record as LocalPaymentPlan).planName;
    case 'payment':
      return '¥${(record as LocalPayment).amount.toStringAsFixed(2)}';
    case 'invoice':
      final i = record as LocalInvoice;
      return i.invoiceNo.isEmpty ? '（未编号发票）' : i.invoiceNo;
    case 'warranty':
      final w = record as LocalWarranty;
      return w.serialNo.isEmpty ? '（未登记序列号）' : w.serialNo;
    case 'product':
      return (record as LocalProduct).name;
    case 'afterSales':
      final t = record as LocalAfterSales;
      return t.ticketNo.isEmpty ? '（未编号工单）' : t.ticketNo;
    default:
      return record.toString();
  }
}

/// 关系候选记录的 id。
String crmRecordId(String type, Object record) {
  switch (type) {
    case 'account':
      return (record as LocalAccount).id;
    case 'contact':
      return (record as LocalContact).id;
    case 'opportunity':
      return (record as LocalOpportunity).id;
    case 'contract':
      return (record as LocalContract).id;
    case 'quote':
      return (record as LocalQuote).id;
    case 'paymentPlan':
      return (record as LocalPaymentPlan).id;
    case 'payment':
      return (record as LocalPayment).id;
    case 'invoice':
      return (record as LocalInvoice).id;
    case 'warranty':
      return (record as LocalWarranty).id;
    case 'product':
      return (record as LocalProduct).id;
    case 'afterSales':
      return (record as LocalAfterSales).id;
    default:
      return record.toString();
  }
}

/// 基础对象字段的展示值格式化（typed → data map）
Map<String, dynamic> accountToDataMap(LocalAccount a) => {
  'name': a.name,
  'type': a.type,
  'industry': a.industry,
  'level': a.level,
  'source': a.source,
  'phone': a.phone,
  'email': a.email,
  'address': a.address,
  'website': a.website,
  'creditCode': a.creditCode,
  'status': a.status,
  'note': a.note,
  'createdAt': a.createdAt.toIso8601String(),
  'updatedAt': a.updatedAt.toIso8601String(),
};

Map<String, dynamic> contactToDataMap(
  LocalContact c, {
  String? accountName,
}) => {
  'name': c.name,
  'accountId': c.accountId,
  'account': accountName == null ? c.accountId : {'name': accountName},
  'title': c.title,
  'department': c.department,
  'phone': c.phone,
  'email': c.email,
  'wechat': c.wechat,
  'isPrimary': c.isPrimary,
  'isDecisionMaker': c.isDecisionMaker,
  'note': c.note,
  'createdAt': c.createdAt.toIso8601String(),
  'updatedAt': c.updatedAt.toIso8601String(),
};

Map<String, dynamic> opportunityToDataMap(
  LocalOpportunity o, {
  String? accountName,
  String? contactName,
}) => {
  'name': o.name,
  'accountId': o.accountId,
  'account': accountName == null ? o.accountId : {'name': accountName},
  'contactId': o.contactId,
  'contact': contactName == null ? o.contactId : {'name': contactName},
  'stage': o.stage,
  'probability': o.probability,
  'amount': o.amount,
  'currency': o.currency,
  'source': o.source,
  'leadContactName': o.leadContactName,
  'leadPhone': o.leadPhone,
  'leadEmail': o.leadEmail,
  'expectedCloseDate': o.expectedCloseDate?.toIso8601String(),
  'actualCloseDate': o.actualCloseDate?.toIso8601String(),
  'lossReason': o.lossReason,
  'note': o.note,
  'createdAt': o.createdAt.toIso8601String(),
  'updatedAt': o.updatedAt.toIso8601String(),
};

Map<String, dynamic> contractToDataMap(
  LocalContract c, {
  String? accountName,
}) => {
  'contractNo': c.contractNo,
  'name': c.name,
  'accountId': c.accountId,
  'account': accountName == null ? c.accountId : {'name': accountName},
  'contactId': c.contactId,
  'status': c.status,
  'currency': c.currency,
  'totalAmount': c.totalAmount,
  'paidAmount': c.paidAmount,
  'invoicedAmount': c.invoicedAmount,
  'signDate': c.signDate?.toIso8601String(),
  'startDate': c.startDate?.toIso8601String(),
  'endDate': c.endDate?.toIso8601String(),
  'warrantyEndDate': c.warrantyEndDate?.toIso8601String(),
  'note': c.note,
  'createdAt': c.createdAt.toIso8601String(),
  'updatedAt': c.updatedAt.toIso8601String(),
};

Map<String, dynamic> productToDataMap(LocalProduct p) => {
  'name': p.name,
  'sku': p.sku,
  'currency': p.currency,
  'type': p.type,
  'unit': p.unit,
  'price': p.price,
  'cost': p.cost,
  'warrantyMonths': p.warrantyMonths,
  'isActive': p.isActive,
  'note': p.note,
  'createdAt': p.createdAt.toIso8601String(),
  'updatedAt': p.updatedAt.toIso8601String(),
};

Map<String, dynamic> quoteToDataMap(
  LocalQuote q, {
  String? accountName,
  String? contactName,
  String? opportunityName,
}) => {
  'quoteNo': q.quoteNo,
  'accountId': q.accountId,
  'account': accountName == null ? q.accountId : {'name': accountName},
  'contactId': q.contactId,
  'contact': contactName == null ? q.contactId : {'name': contactName},
  'opportunityId': q.opportunityId,
  'opportunity': opportunityName == null
      ? q.opportunityId
      : {'name': opportunityName},
  'status': q.status,
  'currency': q.currency,
  'totalAmount': q.totalAmount,
  'discountAmount': q.discountAmount,
  'validUntil': q.validUntil?.toIso8601String(),
  'note': q.note,
  'createdAt': q.createdAt.toIso8601String(),
  'updatedAt': q.updatedAt.toIso8601String(),
};

Map<String, dynamic> paymentPlanToDataMap(
  LocalPaymentPlan p, {
  String? contractName,
}) => {
  'planName': p.planName,
  'contractId': p.contractId,
  'contract': contractName == null ? p.contractId : {'name': contractName},
  'planAmount': p.planAmount,
  'paidAmount': p.paidAmount,
  'planDate': p.planDate.toIso8601String(),
  'status': p.status,
};

Map<String, dynamic> paymentToDataMap(
  LocalPayment p, {
  String? contractName,
  String? planName,
}) => {
  'paymentDate': p.paymentDate.toIso8601String(),
  'contractId': p.contractId,
  'contract': contractName == null ? p.contractId : {'name': contractName},
  'planId': p.planId,
  'plan': planName == null ? p.planId : {'name': planName},
  'amount': p.amount,
  'currency': p.currency,
  'method': p.method,
  'note': p.note,
};

Map<String, dynamic> invoiceToDataMap(
  LocalInvoice i, {
  String? contractName,
}) => {
  'invoiceNo': i.invoiceNo,
  'contractId': i.contractId,
  'contract': contractName == null ? i.contractId : {'name': contractName},
  'type': i.type,
  'amount': i.amount,
  'currency': i.currency,
  'taxRate': i.taxRate,
  'issueDate': i.issueDate?.toIso8601String(),
  'status': i.status,
  'receiverName': i.receiverName,
  'note': i.note,
};

Map<String, dynamic> warrantyToDataMap(
  LocalWarranty w, {
  String? contractName,
  String? productName,
}) => {
  'serialNo': w.serialNo,
  'contractId': w.contractId,
  'contract': contractName == null ? w.contractId : {'name': contractName},
  'productId': w.productId,
  'product': productName == null ? w.productId : {'name': productName},
  'startDate': w.startDate.toIso8601String(),
  'endDate': w.endDate.toIso8601String(),
  'status': w.status,
  'note': w.note,
};

Map<String, dynamic> afterSalesToDataMap(
  LocalAfterSales t, {
  String? accountName,
  String? contactName,
  String? contractName,
}) => {
  'ticketNo': t.ticketNo,
  'subject': t.subject,
  'accountId': t.accountId,
  'account': accountName == null ? t.accountId : {'name': accountName},
  'contactId': t.contactId,
  'contact': contactName == null ? t.contactId : {'name': contactName},
  'contractId': t.contractId,
  'contract': contractName == null ? t.contractId : {'name': contractName},
  'type': t.type,
  'priority': t.priority,
  'status': t.status,
  'description': t.description,
  'resolution': t.resolution,
  'note': t.note,
  'createdAt': t.createdAt.toIso8601String(),
  'updatedAt': t.updatedAt.toIso8601String(),
};

Map<String, dynamic> activityToDataMap(LocalActivity a) => {
  'subject': a.subject,
  'type': a.type,
  'direction': a.direction ?? '',
  'status': a.status,
  'scheduledAt': a.scheduledAt?.toIso8601String(),
  'completedAt': a.completedAt?.toIso8601String(),
  'content': a.content,
  'createdAt': a.createdAt.toIso8601String(),
};

Map<String, dynamic> reminderToDataMap(LocalReminder r) => {
  'title': r.title,
  'type': r.type,
  'remindAt': r.remindAt.toIso8601String(),
  'isCompleted': r.isCompleted,
  'createdAt': r.createdAt.toIso8601String(),
};
