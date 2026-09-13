import 'dart:convert';

import 'package:moodiary/persistence/pref.dart';

/// 个性化画像（对标得到大脑「越用越懂你」）：专业词库 / 常用表达 / 风格偏好。
///
/// 纯数据 + 纯函数；存储走 PrefUtil（key = `aiUserProfile`）。
class UserProfile {
  final List<String> vocabulary;
  final List<String> phrases;
  final String preference;

  const UserProfile({
    this.vocabulary = const [],
    this.phrases = const [],
    this.preference = '',
  });

  bool get isEmpty =>
      vocabulary.isEmpty && phrases.isEmpty && preference.trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'vocabulary': vocabulary,
    'phrases': phrases,
    'preference': preference,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    List<String> readList(String key) =>
        (json[key] as List?)?.map((e) => e.toString()).toList() ?? const [];
    return UserProfile(
      vocabulary: readList('vocabulary'),
      phrases: readList('phrases'),
      preference: json['preference'] as String? ?? '',
    );
  }

  String encode() => jsonEncode(toJson());

  static UserProfile decode(String raw) {
    if (raw.trim().isEmpty) return const UserProfile();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return UserProfile.fromJson(decoded);
    } catch (_) {
      // 容错：坏数据回退空画像
    }
    return const UserProfile();
  }

  /// 注入 Prompt 的偏好段落（空画像返回空串）。
  String toPromptSection() {
    if (isEmpty) return '';
    final buf = StringBuffer('## 用户偏好（请在表达中照顾）\n');
    if (vocabulary.isNotEmpty) {
      buf.writeln('- 专业词库（术语优先用这些写法）：${vocabulary.join('、')}');
    }
    if (phrases.isNotEmpty) {
      buf.writeln('- 常用表达：${phrases.join('；')}');
    }
    if (preference.trim().isNotEmpty) {
      buf.writeln('- 风格偏好：${preference.trim()}');
    }
    return buf.toString().trimRight();
  }
}

/// 画像存储（PrefUtil）。
class UserProfileStore {
  UserProfileStore._();

  static const String key = 'aiUserProfile';

  static UserProfile load() {
    try {
      return UserProfile.decode(PrefUtil.getValue<String>(key) ?? '');
    } catch (_) {
      return const UserProfile();
    }
  }

  static Future<void> save(UserProfile profile) =>
      PrefUtil.setValue(key, profile.encode());
}
