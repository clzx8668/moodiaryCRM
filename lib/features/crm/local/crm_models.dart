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

class LocalCompany {
  String id;
  String name;
  String domainName;
  Map<String, dynamic> address;
  int? employees;
  String linkedinLink;
  String xLink;
  int? arrMicros;
  String icp;
  String customerStatus;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  LocalCompany({
    required this.id,
    this.name = '',
    this.domainName = '',
    Map<String, dynamic>? address,
    this.employees,
    this.linkedinLink = '',
    this.xLink = '',
    this.arrMicros,
    this.icp = '',
    this.customerStatus = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : address = address ?? {},
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

class LocalPerson {
  String id;
  String? companyId;
  String firstName;
  String lastName;
  String jobTitle;
  Map<String, dynamic> emails;
  Map<String, dynamic> phones;
  String city;
  String wechat;
  String avatarUrl;
  String linkedinLink;
  String xLink;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  LocalPerson({
    required this.id,
    this.companyId,
    this.firstName = '',
    this.lastName = '',
    this.jobTitle = '',
    Map<String, dynamic>? emails,
    Map<String, dynamic>? phones,
    this.city = '',
    this.wechat = '',
    this.avatarUrl = '',
    this.linkedinLink = '',
    this.xLink = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : emails = emails ?? {},
       phones = phones ?? {},
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName'.trim();
}

class LocalOpportunity {
  String id;
  String? companyId;
  String? pointOfContactId;
  String name;
  int? amountMicros;
  DateTime? closeDate;
  String stage;
  String customStatus;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  LocalOpportunity({
    required this.id,
    this.companyId,
    this.pointOfContactId,
    this.name = '',
    this.amountMicros,
    this.closeDate,
    this.stage = '',
    this.customStatus = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

class LocalContract {
  String id;
  String? companyId;
  String name;
  int? amountMicros;
  String currency;
  String status;
  DateTime? dueDate;
  String terms;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  LocalContract({
    required this.id,
    this.companyId,
    this.name = '',
    this.amountMicros,
    this.currency = 'CNY',
    this.status = '',
    this.dueDate,
    this.terms = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
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
