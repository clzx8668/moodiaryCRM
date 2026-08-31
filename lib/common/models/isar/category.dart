class Category {
  String id = '';

  late String categoryName;

  String? parentId;

  //分类颜色（ARGB 颜色值），用于分类标识展示，创建时可选/默认指派
  int? color;

  String get level => parentId ?? 'root';

  Category();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryName': categoryName,
      'parentId': parentId,
      'color': color,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category()
      ..id = json['id'] as String
      ..categoryName = json['categoryName'] as String
      ..parentId = json['parentId'] as String?
      ..color = json['color'] as int?;
  }
}
