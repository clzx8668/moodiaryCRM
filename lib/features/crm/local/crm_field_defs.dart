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
  'company': 'name',
  'person': 'name',
  'opportunity': 'name',
  'contract': 'name',
};

const Map<String, List<LocalObjectField>> kBaseObjectFields = {
  'company': [
    LocalObjectField('name', '名称'),
    LocalObjectField('domainName', '域名'),
    LocalObjectField('address', '地址'),
    LocalObjectField('employees', '员工数', type: 'number'),
    LocalObjectField('linkedinLink', '领英'),
    LocalObjectField('xLink', 'X'),
    LocalObjectField('arrMicros', '年经常性收入（元）', type: 'number'),
    LocalObjectField('icp', '理想客户画像'),
    LocalObjectField('customerStatus', '客户状态'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
  'person': [
    LocalObjectField('name', '姓名'),
    LocalObjectField('company', '公司', type: 'relation'),
    LocalObjectField('jobTitle', '职位'),
    LocalObjectField('emails', '邮箱'),
    LocalObjectField('phones', '电话'),
    LocalObjectField('city', '城市'),
    LocalObjectField('wechat', '微信'),
    LocalObjectField('linkedinLink', '领英'),
    LocalObjectField('xLink', 'X'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
  'opportunity': [
    LocalObjectField('name', '名称'),
    LocalObjectField('company', '公司', type: 'relation'),
    LocalObjectField('pointOfContact', '联系人', type: 'relation'),
    LocalObjectField('amountMicros', '金额（元）', type: 'number'),
    LocalObjectField('closeDate', '预计成交日期', type: 'date'),
    LocalObjectField('stage', '阶段', type: 'select', options: [
      '新线索',
      '已联系',
      '方案/报价',
      '谈判中',
      '赢单',
      '输单',
    ]),
    LocalObjectField('customStatus', '自定义状态'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
  'contract': [
    LocalObjectField('name', '合同名称'),
    LocalObjectField('company', '公司', type: 'relation'),
    LocalObjectField('amountMicros', '金额（元）', type: 'number'),
    LocalObjectField('currency', '币种'),
    LocalObjectField('status', '状态', type: 'select', options: [
      '草稿',
      '审批中',
      '已签署',
      '履行中',
      '已完成',
      '已终止',
    ]),
    LocalObjectField('dueDate', '到期日期', type: 'date'),
    LocalObjectField('terms', '条款', type: 'textarea'),
    LocalObjectField('createdAt', '创建时间', type: 'date'),
    LocalObjectField('updatedAt', '更新时间', type: 'date'),
  ],
};

/// 基础对象字段的展示值格式化（typed → data map）
Map<String, dynamic> companyToDataMap(LocalCompany c) => {
  'name': c.name,
  'domainName': c.domainName,
  'address': c.address,
  'employees': c.employees,
  'linkedinLink': c.linkedinLink,
  'xLink': c.xLink,
  'arrMicros': c.arrMicros,
  'icp': c.icp,
  'customerStatus': c.customerStatus,
  'createdAt': c.createdAt.toIso8601String(),
  'updatedAt': c.updatedAt.toIso8601String(),
};

Map<String, dynamic> personToDataMap(
  LocalPerson p, {
  String? companyName,
}) => {
  'name': p.fullName,
  'companyId': p.companyId,
  'company': companyName == null ? p.companyId : {'name': companyName},
  'jobTitle': p.jobTitle,
  'emails': p.emails,
  'phones': p.phones,
  'city': p.city,
  'wechat': p.wechat,
  'linkedinLink': p.linkedinLink,
  'xLink': p.xLink,
  'createdAt': p.createdAt.toIso8601String(),
  'updatedAt': p.updatedAt.toIso8601String(),
};

Map<String, dynamic> opportunityToDataMap(
  LocalOpportunity o, {
  String? companyName,
  String? contactName,
}) => {
  'name': o.name,
  'companyId': o.companyId,
  'company': companyName == null ? o.companyId : {'name': companyName},
  'pointOfContactId': o.pointOfContactId,
  'pointOfContact': contactName == null
      ? o.pointOfContactId
      : {'name': contactName},
  'amountMicros': o.amountMicros,
  'closeDate': o.closeDate?.toIso8601String(),
  'stage': o.stage,
  'customStatus': o.customStatus,
  'createdAt': o.createdAt.toIso8601String(),
  'updatedAt': o.updatedAt.toIso8601String(),
};

Map<String, dynamic> contractToDataMap(
  LocalContract c, {
  String? companyName,
}) => {
  'name': c.name,
  'companyId': c.companyId,
  'company': companyName == null ? c.companyId : {'name': companyName},
  'amountMicros': c.amountMicros,
  'currency': c.currency,
  'status': c.status,
  'dueDate': c.dueDate?.toIso8601String(),
  'terms': c.terms,
  'createdAt': c.createdAt.toIso8601String(),
  'updatedAt': c.updatedAt.toIso8601String(),
};
