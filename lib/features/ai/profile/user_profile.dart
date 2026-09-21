import 'dart:convert';
import 'dart:io';

import 'package:moodiary/features/ai/memory/memory_files.dart';
import 'package:moodiary/features/ai/memory/memory_store.dart';
import 'package:moodiary/persistence/pref.dart';

/// 个性化画像（对标得到大脑「越用越懂你」）：专业词库 / 常用表达 / 风格偏好。
///
/// 纯数据 + 纯函数。
///
/// **批次 119 起**：存储从 `PrefUtil` 的 JSON 升级为 **Markdown 文件**
/// （`<support>/ai-memory/profile.md`，见 [MemoryStore]）——
/// 这样用户可以用 App 自带编辑器直接打开、修改、保存，
/// 也能导出/备份/迁移，不再被表单字段限制。
/// 旧的 JSON 格式仍被支持（[decode] / [encode]）以便无痛迁移与回滚。
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

  // ---------------------------------------------------------- Markdown 互转

  /// 序列化成 Markdown（用户可直接在编辑器里读写）。
  ///
  /// 结构固定为三个二级标题，解析时也按这三个标题取内容——
  /// 用户随手加别的段落不会破坏解析（会被忽略）。
  String toMarkdown() {
    final buf = StringBuffer()
      ..writeln('# 我的画像')
      ..writeln()
      ..writeln('> 这里的内容会注入每一次 AI 处理。')
      ..writeln('> 词库/表达**每行一条**；风格偏好写成一段话即可。')
      ..writeln();
    buf
      ..writeln('## 专业词库')
      ..writeln()
      ..writeln(vocabulary.isEmpty ? '' : vocabulary.map((v) => '- $v').join('\n'))
      ..writeln();
    buf
      ..writeln('## 常用表达')
      ..writeln()
      ..writeln(phrases.isEmpty ? '' : phrases.map((v) => '- $v').join('\n'))
      ..writeln();
    buf
      ..writeln('## 风格偏好')
      ..writeln()
      ..writeln(preference.trim());
    return buf.toString();
  }

  /// 从 Markdown 解析。容错策略：
  /// - 只认那三个二级标题；标题缺失按空处理；
  /// - 列表项支持 `- ` / `* ` / `1. ` 前缀，也接受纯行；
  /// - 解析不出任何内容时返回空画像（不会抛错）。
  static UserProfile fromMarkdown(String md) {
    if (md.trim().isEmpty) return const UserProfile();
    var section = '';
    final vocab = <String>[];
    final phrases = <String>[];
    final preference = <String>[];

    for (final rawLine in md.split('\n')) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();
      if (trimmed.startsWith('## ')) {
        final title = trimmed.substring(3).trim();
        if (title.contains('专业词库') || title.toLowerCase().contains('vocabulary')) {
          section = 'vocab';
        } else if (title.contains('常用表达') ||
            title.toLowerCase().contains('phrase')) {
          section = 'phrase';
        } else if (title.contains('风格偏好') ||
            title.toLowerCase().contains('preference') ||
            title.contains('偏好')) {
          section = 'pref';
        } else {
          section = '';
        }
        continue;
      }
      if (section.isEmpty || trimmed.isEmpty) continue;
      // 去掉列表前缀
      final item = trimmed
          .replaceFirst(RegExp(r'^[-*+]\s+'), '')
          .replaceFirst(RegExp(r'^\d+[.)]\s+'), '')
          .trim();
      if (item.isEmpty) continue;
      switch (section) {
        case 'vocab':
          vocab.add(item);
        case 'phrase':
          phrases.add(item);
        case 'pref':
          preference.add(item);
      }
    }
    return UserProfile(
      vocabulary: vocab,
      phrases: phrases,
      preference: preference.join('\n').trim(),
    );
  }
}

/// 画像存储（PrefUtil）。
class UserProfileStore {
  UserProfileStore._();

  static const String key = 'aiUserProfile';

  /// 同步读取（界面构建时用）：优先读文件，读不到再回退旧 JSON。
  ///
  /// 注意：文件读取是同步 IO，但文件很小（几 KB），
  /// 且只在设置页/注入 prompt 时调用，实测无感。
  static UserProfile load() {
    try {
      final f = File(MemoryFiles.profilePath());
      if (f.existsSync()) return UserProfile.fromMarkdown(f.readAsStringSync());
      return UserProfile.decode(PrefUtil.getValue<String>(key) ?? '');
    } catch (_) {
      return const UserProfile();
    }
  }

  /// 同步写（旧调用方兼容）。写文件 + 快照由 [MemoryStore] 负责。
  static Future<void> save(UserProfile profile) => MemoryStore.saveProfile(profile);
}
