import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moodiary/features/ai/memory/memory_files.dart';
import 'package:moodiary/features/ai/profile/user_profile.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:path/path.dart' as p;

/// 分层记忆的**读写门面**（批次 119）。
///
/// 三层结构（对标 Hermes，但按本项目的实际情况裁剪）：
///
/// | 层 | 载体 | 何时进上下文 |
/// | :-- | :-- | :-- |
/// | **Tier 1** | `profile.md`（用户画像）+ `memory.md`（稳定事实） | **永远**（受字数上限约束） |
/// | **Tier 2** | 自写技能手册 `skills/*.md` | **按需**（命中关键词才注入对应手册） |
/// | **Tier 3** | 笔记向量检索（已由 `RagService` 提供） | 检索命中时 |
///
/// 安全边界（"破坏半径"约束）：
/// - 只写 `<support>/ai-memory/` 自留地**内部**，绝不动用户笔记与设置；
/// - 每次写入前**自动快照**，可一键回滚；
/// - 自动写入必须由调用方显式允许（App 里是"用户点了确认"才落盘）。
class MemoryStore {
  MemoryStore._();

  static const String _legacyProfileKey = 'aiUserProfile';

  static bool _migrated = false;

  // ------------------------------------------------------------ 读

  /// 读取画像（优先文件；文件不存在时从旧的 PrefUtil JSON 迁移一次）
  static Future<UserProfile> loadProfile() async {
    await _ensureReady();
    final file = File(MemoryFiles.profilePath());
    if (file.existsSync()) {
      return UserProfile.fromMarkdown(file.readAsStringSync());
    }
    // 首次使用：把老数据迁过来，迁移后仍保留旧 key（回滚用）
    String legacyRaw = '';
    try {
      legacyRaw = PrefUtil.getValue<String>(_legacyProfileKey) ?? '';
    } catch (_) {
      // PrefUtil 未初始化（单测/极早期调用）：当作没有旧数据
    }
    if (legacyRaw.trim().isEmpty) return const UserProfile();
    final legacy = UserProfile.decode(legacyRaw);
    if (!legacy.isEmpty) {
      await saveProfile(legacy, snapshot: false);
    }
    return legacy;
  }

  /// 稳定事实（Tier 1 的第二个文件）
  static Future<String> loadMemory() async {
    await _ensureReady();
    final file = File(MemoryFiles.memoryPath());
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  /// 自写技能手册：返回 `标题 → 正文`
  static Future<Map<String, String>> loadSkills() async {
    await _ensureReady();
    final out = <String, String>{};
    for (final f in MemoryFiles.listSkillFiles()) {
      final title = p.basenameWithoutExtension(f.path);
      out[title] = f.readAsStringSync();
    }
    return out;
  }

  // ------------------------------------------------------------ 写

  /// 保存画像（写 `profile.md`；写前自动快照）
  static Future<void> saveProfile(
    UserProfile profile, {
    bool snapshot = true,
  }) async {
    await _ensureReady();
    if (snapshot) await _snapshot(MemoryFiles.profileName);
    await File(
      MemoryFiles.profilePath(),
    ).writeAsString(profile.toMarkdown(), flush: true);
  }

  /// 保存稳定事实（写 `memory.md`）
  static Future<void> saveMemory(String markdown, {bool snapshot = true}) async {
    await _ensureReady();
    if (snapshot) await _snapshot(MemoryFiles.memoryName);
    await File(
      MemoryFiles.memoryPath(),
    ).writeAsString(markdown, flush: true);
  }

  /// 追加一段到 `memory.md`（AI 自学习写回时用；带时间戳小标题）
  static Future<void> appendMemory(
    String section, {
    DateTime? now,
    bool snapshot = true,
  }) async {
    final t = section.trim();
    if (t.isEmpty) return;
    final existing = await loadMemory();
    final stamp = (now ?? DateTime.now())
        .toIso8601String()
        .substring(0, 16)
        .replaceFirst('T', ' ');
    final buf = StringBuffer();
    if (existing.trim().isNotEmpty) {
      buf.writeln(existing.trimRight());
      buf.writeln();
    }
    buf.writeln('## $stamp');
    buf.writeln(t);
    await saveMemory(buf.toString(), snapshot: snapshot);
  }

  /// 新建/覆盖一个技能手册
  static Future<void> saveSkill(
    String title,
    String markdown, {
    bool snapshot = true,
  }) async {
    await _ensureReady();
    final slug = MemoryFiles.slugify(title);
    final file = File(p.join(MemoryFiles.skillsDir(), '$slug.md'));
    if (snapshot && file.existsSync()) await _snapshot('skills/$slug.md');
    await file.writeAsString(markdown, flush: true);
  }

  /// 保存画像文件的**原始文本**（用户在编辑器里手写的结构不被改写）。
  ///
  /// 与 [saveProfile] 的区别：那个会把结构规范成三节标题，
  /// 这个只落盘用户写的东西——尊重用户自己的排版。
  static Future<void> saveRawProfileText(String markdown) async {
    await _ensureReady();
    await _snapshot(MemoryFiles.profileName);
    await File(
      MemoryFiles.profilePath(),
    ).writeAsString(markdown, flush: true);
  }

  /// 保存自留地内的任意文件（编辑器通用入口；写前快照）
  static Future<void> saveRawFile(String path, String content) async {
    await _ensureReady();
    final rel = p.relative(path, from: MemoryFiles.rootDir());
    if (!rel.startsWith('..')) await _snapshot(rel);
    await File(path).writeAsString(content, flush: true);
  }

  /// 删除一个技能手册（同样先快照，可回滚）
  static Future<bool> deleteSkill(String title) async {
    await _ensureReady();
    final slug = MemoryFiles.slugify(title);
    final file = File(p.join(MemoryFiles.skillsDir(), '$slug.md'));
    if (!file.existsSync()) return false;
    await _snapshot('skills/$slug.md');
    await file.delete();
    return true;
  }

  // ------------------------------------------------------------ 注入上下文

  /// 构造要注入 Prompt 的分层记忆段落。
  ///
  /// - [query]：当前任务文本。给了就**按关键词挑相关的技能手册**（Tier 2 按需），
  ///   没给就只注入 Tier 1（画像 + 稳定事实）。
  /// - 受 [MemoryFiles.maxInjectedCharsTotal] 限制，不会把上下文挤爆。
  static Future<String> buildPromptSection({String query = ''}) async {
    await _ensureReady();
    final buf = StringBuffer();
    var budget = MemoryFiles.maxInjectedCharsTotal;

    final profile = await loadProfile();
    final profileSection = profile.toPromptSection();
    if (profileSection.trim().isNotEmpty) {
      final cut = _clip(
        profileSection,
        MemoryFiles.maxInjectedCharsPerFile,
      );
      buf.writeln(cut);
      buf.writeln();
      budget -= cut.length;
    }

    final memory = (await loadMemory()).trim();
    if (memory.isNotEmpty && budget > 0) {
      final cut = _clip(memory, budget.clamp(0, MemoryFiles.maxInjectedCharsPerFile));
      buf.writeln('## 长期记忆（用户确认过的稳定事实）');
      buf.writeln(cut);
      buf.writeln();
      budget -= cut.length;
    }

    // Tier 2：按需挑技能手册
    if (query.trim().isNotEmpty && budget > 0) {
      final picked = await pickRelevantSkills(query);
      for (final entry in picked) {
        if (budget <= 0) break;
        final cut = _clip(entry.value, budget.clamp(0, 2000));
        buf.writeln('## 技能手册：${entry.key}');
        buf.writeln(cut);
        buf.writeln();
        budget -= cut.length;
      }
    }

    return buf.toString().trimRight();
  }

  /// 关键词挑选相关技能手册（纯本地、零成本）
  static Future<List<MapEntry<String, String>>> pickRelevantSkills(
    String query,
  ) async {
    final skills = await loadSkills();
    if (skills.isEmpty) return const [];
    final q = query.trim();
    final scored = <({String title, String body, int score})>[];
    for (final e in skills.entries) {
      var score = 0;
      // 标题直接出现 → 强相关
      if (q.contains(e.key)) score += 5;
      // 标题里的词逐字命中
      for (final ch in e.key.runes) {
        if (q.contains(String.fromCharCode(ch))) score += 1;
      }
      // 正文关键词命中（取手册里的二级标题词）
      for (final line in e.value.split('\n')) {
        final t = line.replaceAll(RegExp(r'^#+\s*'), '').trim();
        if (t.length >= 2 && t.length <= 12 && q.contains(t)) score += 2;
      }
      if (score > 0) scored.add((title: e.key, body: e.value, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored
        .take(2)
        .map((e) => MapEntry(e.title, e.body))
        .toList();
  }

  // ------------------------------------------------------------ 快照 / 回滚

  /// 写入前快照（`snapshots/<名字>.<时间戳>.md`）
  static Future<void> _snapshot(String relativeName) async {
    try {
      final src = File(p.join(MemoryFiles.rootDir(), relativeName));
      if (!src.existsSync()) return;
      final flat = relativeName.replaceAll('/', '__');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final dst = File(p.join(MemoryFiles.snapshotsDir(), '$flat.$stamp.md'));
      await dst.writeAsString(src.readAsStringSync(), flush: true);
      await _pruneSnapshots();
    } catch (e) {
      // 快照失败不阻断主流程（但要能被发现）
      debugPrint('[MemoryStore] 快照失败：$e');
    }
  }

  /// 每类文件最多保留 N 份快照，避免无限增长
  static const int maxSnapshotsPerFile = 10;

  static Future<void> _pruneSnapshots() async {
    final dir = Directory(MemoryFiles.snapshotsDir());
    if (!dir.existsSync()) return;
    final all = dir.listSync().whereType<File>().toList()
      ..sort((a, b) {
        // 按时间戳数值倒序（见 listSnapshotsNewestFirst 的说明）
        int stamp(String path) {
          final m = RegExp(r'\.(\d{10,})\.md$').firstMatch(path);
          return m == null ? 0 : (int.tryParse(m.group(1)!) ?? 0);
        }

        return stamp(b.path).compareTo(stamp(a.path));
      });
    final kept = <String, int>{};
    for (final f in all) {
      final base = p.basename(f.path).replaceAll(RegExp(r'\.\d+\.md$'), '');
      final n = (kept[base] ?? 0) + 1;
      kept[base] = n;
      if (n > maxSnapshotsPerFile) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// 最近一次快照（用于"撤销上次自动写入"）
  static Map<String, String> listSnapshots() {
    final dir = Directory(MemoryFiles.snapshotsDir());
    if (!dir.existsSync()) return const {};
    final out = <String, String>{};
    for (final f in dir.listSync().whereType<File>()) {
      out[p.basename(f.path)] = f.path;
    }
    return out;
  }

  /// 按**时间倒序**返回快照文件名（新的在前）。
  ///
  /// 直接用文件名字符串排序是错的：时间戳长度相同但数值大小与字典序不一致，
  /// 这里显式解析出时间戳再做数值比较。
  static List<String> listSnapshotsNewestFirst() {
    final names = listSnapshots().keys.toList();
    int stampOf(String n) {
      final m = RegExp(r'\.(\d{10,})\.md$').firstMatch(n);
      return m == null ? 0 : (int.tryParse(m.group(1)!) ?? 0);
    }

    names.sort((a, b) => stampOf(b).compareTo(stampOf(a)));
    return names;
  }

  /// 回滚到指定快照
  static Future<bool> restoreSnapshot(String snapshotFileName) async {
    await _ensureReady();
    final src = File(p.join(MemoryFiles.snapshotsDir(), snapshotFileName));
    if (!src.existsSync()) return false;
    // 快照名形如 `skills__x.md.1730000000000.md`
    // 1) 先把 `__` 还原成路径分隔符（否则会去建一个名叫 `skills__x.md` 的文件）
    final relativeName = snapshotFileName.replaceAll('__', '/');
    // 2) 再去掉时间戳后缀，得到原名 `skills/x.md`
    final target = relativeName.replaceFirst(RegExp(r'\.\d{10,}\.md$'), '');
    final dst = File(p.join(MemoryFiles.rootDir(), target));
    await dst.create(recursive: true);
    await dst.writeAsString(src.readAsStringSync(), flush: true);
    return true;
  }

  // ------------------------------------------------------------ 杂项

  /// 首次调用时建目录 + 迁移一次
  static Future<void> _ensureReady() async {
    if (_migrated) return;
    _migrated = true;
    try {
      await MemoryFiles.ensureDirs();
    } catch (e) {
      debugPrint('[MemoryStore] 建目录失败：$e');
    }
    // 给 memory.md 一个带说明的初始模板，用户一打开就知道能写什么
    final mem = File(MemoryFiles.memoryPath());
    if (!mem.existsSync()) {
      await mem.writeAsString(_memoryTemplate, flush: true);
    }
  }

  static const String _memoryTemplate = '''
# 长期记忆

> 这里放**稳定、长期有效**的事实与偏好（比如"我常驻上海""我的客户主要在制造业"）。
> 它会**始终**参与 AI 的上下文，所以请只写长期有效的内容，别把一次性的事写进来。
> 一次性的事交给笔记本身，AI 会通过检索找到。

''';

  /// 调试用：当前分层记忆的体量概览
  static Future<Map<String, int>> stats() async {
    await _ensureReady();
    return {
      'profile': File(MemoryFiles.profilePath()).existsSync()
          ? File(MemoryFiles.profilePath()).lengthSync()
          : 0,
      'memory': File(MemoryFiles.memoryPath()).existsSync()
          ? File(MemoryFiles.memoryPath()).lengthSync()
          : 0,
      'skills': MemoryFiles.listSkillFiles().length,
    };
  }

  static String _clip(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}…（已截断）';

  /// 仅供测试
  static void resetForTest() => _migrated = false;

  /// 仅供测试：显式建目录（避免依赖 PrefUtil 初始化顺序）
  @visibleForTesting
  static Future<void> ensureDirsForTest() async {
    _migrated = false;
    await _ensureReady();
  }

  /// 显式初始化（建目录 + 铺 memory.md 模板）。
  ///
  /// 界面在"只想展示体量"时也会调用它，保证用户一进设置页就能看到这几个文件，
  /// 而不是等第一次 AI 处理才凭空出现。
  static Future<void> ensureReady() => _ensureReady();

  /// 导入旧 JSON（兼容测试与迁移）
  static String encodeLegacy(UserProfile p) => jsonEncode(p.toJson());
}
