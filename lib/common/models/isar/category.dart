class Category {
  String id = '';

  late String categoryName;

  String? parentId;

  String get level => parentId ?? 'root';

  Category();

  Map<String, dynamic> toJson() {
    return {'id': id, 'categoryName': categoryName, 'parentId': parentId};
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category()
      ..id = json['id'] as String
      ..categoryName = json['categoryName'] as String
      ..parentId = json['parentId'] as String?;
  }
}
