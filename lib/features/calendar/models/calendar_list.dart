import 'package:moodiary/persistence/app_database.dart';

/// iOS 18 日历系统色 + 新建日历可选色板。
class CalendarColors {
  /// 今天（iOS 红）
  static const int today = 0xFFFF3B30;

  static const int blue = 0xFF0A84FF;
  static const int green = 0xFF30D158;
  static const int orange = 0xFFFF9F0A;
  static const int purple = 0xFFBF5AF2;
  static const int teal = 0xFF40C8E0;
  static const int pink = 0xFFFF375F;
  static const int yellow = 0xFFFFD60A;
  static const int indigo = 0xFF5E5CE6;
  static const int brown = 0xFFAC8E68;
  static const int gray = 0xFF8E8E93;

  /// 新建日历时可选的色板（顺序即展示顺序）。
  static const List<int> palette = [
    blue,
    green,
    orange,
    purple,
    pink,
    yellow,
    indigo,
    teal,
    brown,
    gray,
  ];

  /// 日历名的推荐配色（工作蓝 / 生活绿 / 家庭橙 / 旅行紫 / 个人蓝）。
  static int suggestByName(String name) => switch (name) {
    '工作' => blue,
    '生活' => green,
    '家庭' => orange,
    '旅行' => purple,
    '个人' => blue,
    _ => palette[name.length % palette.length],
  };
}

/// 日历实体（多日历 + 颜色 + 显示开关）。
class CalendarList {
  String id;
  String name;
  int color;
  bool visible;
  bool isDefault;
  String source;
  int sharedCount;
  int sortOrder;
  bool deleted;
  DateTime createdAt;
  DateTime updatedAt;

  CalendarList({
    required this.id,
    required this.name,
    required this.color,
    this.visible = true,
    this.isDefault = false,
    this.source = 'local',
    this.sharedCount = 0,
    this.sortOrder = 0,
    this.deleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// 只读日历（订阅源：iCloud / Hermes 下发的）不允许本地改名改色。
  bool get readOnly => source != 'local';

  bool get isShared => sharedCount > 0;

  CalendarList clone() => CalendarList(
    id: id,
    name: name,
    color: color,
    visible: visible,
    isDefault: isDefault,
    source: source,
    sharedCount: sharedCount,
    sortOrder: sortOrder,
    deleted: deleted,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt.millisecondsSinceEpoch),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt.millisecondsSinceEpoch),
  );

  static CalendarList fromRow(CalendarRow row) => CalendarList(
    id: row.id,
    name: row.name,
    color: row.color,
    visible: row.visible,
    isDefault: row.isDefault,
    source: row.source,
    sharedCount: row.sharedCount,
    sortOrder: row.sortOrder,
    deleted: row.deleted,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'visible': visible,
    'isDefault': isDefault,
    'source': source,
    'sharedCount': sharedCount,
    'sortOrder': sortOrder,
    'deleted': deleted,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CalendarList.fromJson(Map<String, dynamic> json) => CalendarList(
    id: json['id'] as String,
    name: json['name'] as String? ?? '未命名',
    color: (json['color'] as num?)?.toInt() ?? CalendarColors.blue,
    visible: json['visible'] as bool? ?? true,
    isDefault: json['isDefault'] as bool? ?? false,
    source: json['source'] as String? ?? 'local',
    sharedCount: (json['sharedCount'] as num?)?.toInt() ?? 0,
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    deleted: json['deleted'] as bool? ?? false,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.tryParse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.tryParse(json['updatedAt'] as String),
  );
}
