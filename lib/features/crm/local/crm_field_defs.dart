library;

import 'crm_models.dart';

/// 本地 CRM 字段定义（基础对象默认展示字段，参照成熟 CRM 视图）。

class LocalObjectField {
  final String name;
  final String label;
  final String type; // text / number / date / select / textarea / relation
  final List<String> options;

  const LocalObjectField(
    this.name,
    this.label, {
    this.type = 'text',
    this.options = const [],
  });
}

/// 各基础对象的标签标识字段
const Map<String, String> kLocalLabelFields = {
  'account': 'name',
  'contact': 'name',
  'opportunity': 'name',
  'contract': 'name',
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
    LocalObjectField('amount', '预计金额（元）', type: 'number'),
    LocalObjectField('currency', '币种'),
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
    LocalObjectField('status', '状态', type: 'select', options: [
      'draft',
      'active',
      'completed',
      'terminated',
      'expired',
    ]),
    LocalObjectField('totalAmount', '总金额（元）', type: 'number'),
    LocalObjectField('paidAmount', '已回款（元）', type: 'number'),
    LocalObjectField('invoicedAmount', '已开票（元）', type: 'number'),
    LocalObjectField('signDate', '签约日期', type: 'date'),
    LocalObjectField('startDate', '开始日期', type: 'date'),
    LocalObjectField('endDate', '结束日期', type: 'date'),
    LocalObjectField('warrantyEndDate', '质保到期', type: 'date'),
    LocalObjectField('note', '备注', type: 'textarea'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
};

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
