library;

/// 本地优先 CRM 模型（参照 SuiteCRM/EspoCRM/Twenty 经典数据模型精简）。

/// 字段定义（自定义对象元数据）
class CrmFieldDef {
  final String name;
  final String label;
  final String type; // text / number / date / select / boolean / textarea
  final List<String> options;
  final bool required;
  final int order;

  const CrmFieldDef({
    required this.name,
    required this.label,
    this.type = 'text',
    this.options = const [],
    this.required = false,
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'label': label,
    'type': type,
    'options': options,
    'required': required,
    'order': order,
  };

  factory CrmFieldDef.fromJson(Map<String, dynamic> json) => CrmFieldDef(
    name: json['name'] as String,
    label: json['label'] as String? ?? json['name'] as String,
    type: json['type'] as String? ?? 'text',
    options: ((json['options'] as List?) ?? []).cast<String>(),
    required: json['required'] as bool? ?? false,
    order: (json['order'] as num?)?.toInt() ?? 0,
  );
}

/// 客户/账户（统一承载 company / person / org）
class LocalAccount {
  String id;
  String name;
  String type;
  String industry;
  String level;
  String source;
  String phone;
  String email;
  String address;
  String website;
  String creditCode;
  String note;
  String status;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  LocalAccount({
    required this.id,
    this.name = '',
    this.type = 'company',
    this.industry = '',
    this.level = 'normal',
    this.source = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.website = '',
    this.creditCode = '',
    this.note = '',
    this.status = 'active',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// 联系人（从属 Account）
class LocalContact {
  String id;
  String? accountId;
  String name;
  String title;
  String department;
  String phone;
  String email;
  String wechat;
  bool isPrimary;
  bool isDecisionMaker;
  String note;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  LocalContact({
    required this.id,
    this.accountId,
    this.name = '',
    this.title = '',
    this.department = '',
    this.phone = '',
    this.email = '',
    this.wechat = '',
    this.isPrimary = false,
    this.isDecisionMaker = false,
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

class LocalOpportunity {
  String id;
  String? accountId;
  String? contactId;
  String name;
  String stage;
  int probability;
  double amount;
  String currency;
  String source;
  String leadContactName;
  String leadPhone;
  String leadEmail;
  DateTime? expectedCloseDate;
  DateTime? actualCloseDate;
  String lossReason;
  String note;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  LocalOpportunity({
    required this.id,
    this.accountId,
    this.contactId,
    this.name = '',
    this.stage = 'newLead',
    this.probability = 0,
    this.amount = 0,
    this.currency = 'CNY',
    this.source = '',
    this.leadContactName = '',
    this.leadPhone = '',
    this.leadEmail = '',
    this.expectedCloseDate,
    this.actualCloseDate,
    this.lossReason = '',
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

class LocalContract {
  String id;
  String contractNo;
  String name;
  String? accountId;
  String? contactId;
  String? opportunityId;
  String? quoteId;
  String status;
  double totalAmount;
  double paidAmount;
  double invoicedAmount;
  DateTime? signDate;
  DateTime? startDate;
  DateTime? endDate;
  DateTime? warrantyEndDate;
  String note;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  LocalContract({
    required this.id,
    this.contractNo = '',
    this.name = '',
    this.accountId,
    this.contactId,
    this.opportunityId,
    this.quoteId,
    this.status = 'draft',
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.invoicedAmount = 0,
    this.signDate,
    this.startDate,
    this.endDate,
    this.warrantyEndDate,
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// 产品分类
class LocalProductCategory {
  String id;
  String name;
  String? parentId;

  LocalProductCategory({
    required this.id,
    required this.name,
    this.parentId,
  });
}

/// 产品/服务
class LocalProduct {
  String id;
  String? categoryId;
  String name;
  String sku;
  String type;
  String unit;
  double price;
  double cost;
  int warrantyMonths;
  bool isActive;
  String note;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  LocalProduct({
    required this.id,
    this.categoryId,
    this.name = '',
    this.sku = '',
    this.type = 'product',
    this.unit = '',
    this.price = 0,
    this.cost = 0,
    this.warrantyMonths = 0,
    this.isActive = true,
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// 报价单
class LocalQuote {
  String id;
  String quoteNo;
  String? opportunityId;
  String? accountId;
  String? contactId;
  String status;
  double totalAmount;
  double discountAmount;
  DateTime? validUntil;
  String note;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  LocalQuote({
    required this.id,
    this.quoteNo = '',
    this.opportunityId,
    this.accountId,
    this.contactId,
    this.status = 'draft',
    this.totalAmount = 0,
    this.discountAmount = 0,
    this.validUntil,
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// 报价明细
class LocalQuoteItem {
  String id;
  String quoteId;
  String? productId;
  String productName;
  double quantity;
  double unitPrice;
  double discount;
  double amount;
  int sortOrder;

  LocalQuoteItem({
    required this.id,
    required this.quoteId,
    this.productId,
    this.productName = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.discount = 1,
    this.amount = 0,
    this.sortOrder = 0,
  });
}

/// 合同明细
class LocalContractItem {
  String id;
  String contractId;
  String? productId;
  String productName;
  double quantity;
  double unitPrice;
  double amount;
  int warrantyMonths;
  int sortOrder;

  LocalContractItem({
    required this.id,
    required this.contractId,
    this.productId,
    this.productName = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.amount = 0,
    this.warrantyMonths = 0,
    this.sortOrder = 0,
  });
}

/// 自定义数据对象定义
class LocalCustomObject {
  String id;
  String labelSingular;
  String labelPlural;
  String icon;
  List<CrmFieldDef> fields;
  bool builtin;
  DateTime createdAt;
  DateTime updatedAt;

  LocalCustomObject({
    required this.id,
    required this.labelSingular,
    required this.labelPlural,
    this.icon = '',
    List<CrmFieldDef>? fields,
    this.builtin = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : fields = fields ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// 自定义对象记录
class LocalCustomRecord {
  String id;
  String objectId;
  String label;
  Map<String, dynamic> data;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  LocalCustomRecord({
    required this.id,
    required this.objectId,
    this.label = '',
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : data = data ?? {},
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// 本地实体 ↔ 日记/待办关联
class LocalEntityLink {
  String id;
  String entityType;
  String entityId;
  String localType;
  String localId;
  String relation;
  DateTime createdAt;

  LocalEntityLink({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.localType,
    required this.localId,
    this.relation = 'followup',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
