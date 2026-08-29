import 'package:moodiary/features/crm/local/crm_entity_creator.dart';
import 'package:moodiary/features/crm/local/crm_entity_field_updater.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';

/// CRM 写操作提案（M6）：AI 提议 crm_create/update/delete 时先构建提案，
/// 由 UI 展示「确认卡片」，用户确认后才执行。
class CrmWriteProposal {
  /// create / update / delete
  final String action;
  final String actionLabel;
  final String objectType;
  final String objectLabel;
  final String? id;
  final Map<String, dynamic> fields;

  /// 展示名（update/delete 优先取数据库当前名称，否则取 fields['name']）。
  final String targetName;

  const CrmWriteProposal({
    required this.action,
    required this.actionLabel,
    required this.objectType,
    required this.objectLabel,
    this.id,
    required this.fields,
    required this.targetName,
  });
}

/// CRM 写工具服务：构建提案 + 执行写操作 + 同步日志。
class CrmWriteService {
  CrmWriteService._();

  static const Map<String, String> objectLabels = {
    'account': '客户',
    'contact': '联系人',
    'opportunity': '商机',
    'contract': '合同',
    'product': '产品',
    'quote': '报价单',
    'paymentPlan': '付款计划',
    'payment': '回款',
    'invoice': '发票',
    'warranty': '质保',
    'afterSales': '售后工单',
    'activity': '跟进记录',
    'reminder': '提醒',
  };

  static const Map<String, String> fieldLabels = {
    'name': '名称',
    'type': '类型',
    'industry': '行业',
    'level': '等级',
    'source': '来源',
    'phone': '电话',
    'email': '邮箱',
    'address': '地址',
    'website': '网站',
    'creditCode': '信用代码',
    'note': '备注',
    'status': '状态',
    'title': '职务',
    'department': '部门',
    'wechat': '微信',
    'isPrimary': '主要联系人',
    'isDecisionMaker': '决策人',
    'accountId': '所属客户',
    'contactId': '联系人',
    'opportunityId': '商机',
    'contractId': '合同',
    'quoteId': '报价单',
    'stage': '阶段',
    'probability': '赢率(%)',
    'amount': '金额',
    'currency': '币种',
    'totalAmount': '总金额',
    'paidAmount': '已收金额',
    'invoicedAmount': '开票金额',
    'signDate': '签订日期',
    'startDate': '开始日期',
    'endDate': '结束日期',
    'contractNo': '合同编号',
    'sku': 'SKU',
    'unit': '单位',
    'price': '单价',
    'cost': '成本',
    'warrantyMonths': '质保(月)',
    'isActive': '启用',
    'quoteNo': '报价编号',
    'discountAmount': '折扣金额',
    'validUntil': '有效期至',
    'planName': '计划名称',
    'planAmount': '计划金额',
    'planDate': '计划日期',
    'paymentDate': '回款日期',
    'method': '方式',
    'invoiceNo': '发票号',
    'taxRate': '税率',
    'issueDate': '开票日期',
    'receiverName': '发票抬头',
    'serialNo': '序列号',
    'subject': '主题',
    'priority': '优先级',
    'description': '描述',
    'resolution': '解决方案',
    'direction': '方向',
    'scheduledAt': '计划时间',
    'remindAt': '提醒时间',
    'isCompleted': '已完成',
    'amountCurrency': '币种',
    'totalAmountCurrency': '币种',
    'priceCurrency': '币种',
    'planAmountCurrency': '币种',
    'discountAmountCurrency': '币种',
  };

  /// 把 AI 参数构建成可确认的提案；参数不合法时抛 ArgumentError。
  static Future<CrmWriteProposal> buildProposal({
    required String action,
    required Map<String, dynamic> args,
  }) async {
    if (action != 'create' && action != 'update' && action != 'delete') {
      throw ArgumentError('不支持的操作 $action');
    }
    final object = (args['object'] ?? args['objectType'] ?? '')
        .toString()
        .trim();
    if (object.isEmpty) {
      throw ArgumentError('缺少对象类型 object（如 account/contact/opportunity）');
    }
    final id = (args['id']?.toString() ?? '').trim();
    final rawFields = args['fields'];
    final Map<String, dynamic> fields;
    if (rawFields is Map) {
      fields = rawFields.map((k, v) => MapEntry(k.toString(), v));
    } else {
      fields = {};
    }

    if (action == 'create' && fields.isEmpty) {
      throw ArgumentError('创建操作缺少字段 fields');
    }
    if (action == 'update') {
      if (id.isEmpty) throw ArgumentError('更新操作缺少记录 id');
      if (fields.isEmpty) throw ArgumentError('更新操作缺少字段 fields');
    }
    if (action == 'delete' && id.isEmpty) {
      throw ArgumentError('删除操作缺少记录 id');
    }

    final objectLabel = objectLabels[object] ?? '自定义对象';
    final actionLabel = switch (action) {
      'create' => '创建',
      'update' => '更新',
      _ => '删除',
    };

    var targetName = fields['name']?.toString() ?? '';
    if (action != 'create' && id.isNotEmpty) {
      final dbName = await _resolveName(object, id);
      if (dbName != null && dbName.trim().isNotEmpty) {
        targetName = dbName;
      }
    }

    return CrmWriteProposal(
      action: action,
      actionLabel: actionLabel,
      objectType: object,
      objectLabel: objectLabel,
      id: id.isEmpty ? null : id,
      fields: fields,
      targetName: targetName,
    );
  }

  /// 执行已确认的写操作，返回给 AI 的结果文本；失败抛异常。
  static Future<String> execute(CrmWriteProposal p) async {
    final repo = CrmLocalRepository();
    switch (p.action) {
      case 'create':
        final newId = await createCrmEntity(
          repo: repo,
          objectType: p.objectType,
          data: p.fields,
        );
        final display =
            p.fields['name']?.toString().trim().isNotEmpty == true
            ? p.fields['name'].toString()
            : newId;
        await _log(
          p,
          '创建${p.objectLabel}「$display」id=$newId',
        );
        return '已创建${p.objectLabel}「$display」（id=$newId）';
      case 'update':
        if (!await _exists(p.objectType, p.id!)) {
          throw StateError('未找到${p.objectLabel}（id=${p.id}）');
        }
        var count = 0;
        for (final entry in p.fields.entries) {
          await CrmEntityFieldUpdater.update(
            objectType: p.objectType,
            id: p.id!,
            field: entry.key,
            value: entry.value,
          );
          count++;
        }
        final display = p.targetName.isEmpty ? p.id! : p.targetName;
        await _log(p, '更新${p.objectLabel}「$display」共 $count 个字段');
        return '已更新${p.objectLabel}「$display」共 $count 个字段';
      case 'delete':
        if (!await _exists(p.objectType, p.id!)) {
          throw StateError('未找到${p.objectLabel}（id=${p.id}）');
        }
        await CrmEntityDeleter.delete(p.objectType, p.id!);
        final display = p.targetName.isEmpty ? p.id! : p.targetName;
        await _log(p, '删除${p.objectLabel}「$display」');
        return '已删除${p.objectLabel}「$display」';
    }
    throw StateError('未知操作 ${p.action}');
  }

  static Future<void> _log(CrmWriteProposal p, String detail) async {
    await SyncLogService.instance.write(
      level: SyncLogLevel.info,
      operation: 'crm_write',
      target: p.objectType,
      detail: 'AI ${p.actionLabel}${p.objectLabel}：$detail',
    );
  }

  static Future<String?> _resolveName(String objectType, String id) async {
    final repo = CrmLocalRepository();
    switch (objectType) {
      case 'account':
        return (await repo.getAccount(id))?.name;
      case 'contact':
        return (await repo.getContact(id))?.name;
      case 'opportunity':
        return (await repo.getOpportunity(id))?.name;
      case 'contract':
        return (await repo.getContract(id))?.name;
      case 'product':
        return (await repo.getProduct(id))?.name;
      case 'quote':
        return (await repo.getQuote(id))?.quoteNo;
      case 'paymentPlan':
        return (await repo.getPaymentPlan(id))?.planName;
      case 'invoice':
        return (await repo.getInvoice(id))?.invoiceNo;
      case 'warranty':
        return (await repo.getWarranty(id))?.serialNo;
      case 'afterSales':
        return (await repo.getAfterSales(id))?.subject;
      case 'activity':
        return (await repo.getActivity(id))?.subject;
      case 'reminder':
        return (await repo.getReminder(id))?.title;
      default:
        return (await repo.getCustomRecord(id))?.label;
    }
  }

  static Future<bool> _exists(String objectType, String id) async {
    final repo = CrmLocalRepository();
    switch (objectType) {
      case 'account':
        return (await repo.getAccount(id)) != null;
      case 'contact':
        return (await repo.getContact(id)) != null;
      case 'opportunity':
        return (await repo.getOpportunity(id)) != null;
      case 'contract':
        return (await repo.getContract(id)) != null;
      case 'product':
        return (await repo.getProduct(id)) != null;
      case 'quote':
        return (await repo.getQuote(id)) != null;
      case 'paymentPlan':
        return (await repo.getPaymentPlan(id)) != null;
      case 'payment':
        return (await repo.getPayment(id)) != null;
      case 'invoice':
        return (await repo.getInvoice(id)) != null;
      case 'warranty':
        return (await repo.getWarranty(id)) != null;
      case 'afterSales':
        return (await repo.getAfterSales(id)) != null;
      case 'activity':
        return (await repo.getActivity(id)) != null;
      case 'reminder':
        return (await repo.getReminder(id)) != null;
      default:
        return (await repo.getCustomRecord(id)) != null;
    }
  }
}
