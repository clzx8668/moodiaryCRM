import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/memory/memory_files.dart';
import 'package:moodiary/features/ai/memory/memory_store.dart';
import 'package:moodiary/features/ai/profile/user_profile.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('memory_test');
    // 单测没有真实的 supportPath，直接覆盖记忆目录
    MemoryFiles.rootDirOverride = p.join(tempDir.path, MemoryFiles.rootName);
    MemoryStore.resetForTest();
  });

  tearDown(() {
    MemoryFiles.rootDirOverride = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('MemoryFiles｜目录与文件名', () {
    test('路径都落在 ai-memory 自留地内', () {
      final root = MemoryFiles.rootDir();
      expect(root.endsWith(MemoryFiles.rootName), isTrue);
      expect(MemoryFiles.profilePath(), p.join(root, 'profile.md'));
      expect(MemoryFiles.memoryPath(), p.join(root, 'memory.md'));
      expect(MemoryFiles.skillsDir(), p.join(root, 'skills'));
      expect(MemoryFiles.snapshotsDir(), p.join(root, 'snapshots'));
    });

    test('slugify：去非法字符、压短横线、超长截断、空名兜底', () {
      expect(MemoryFiles.slugify('客户报价流程'), '客户报价流程');
      expect(MemoryFiles.slugify('客户/报价:流程'), '客户-报价-流程');
      expect(MemoryFiles.slugify('  a   b  '), 'a-b');
      expect(MemoryFiles.slugify('!!!'), 'skill');
      expect(MemoryFiles.slugify('长' * 100).length, 40);
    });
  });

  group('UserProfile｜Markdown 互转', () {
    test('往返保持三个字段', () {
      const p0 = UserProfile(
        vocabulary: ['膜池', 'MBR'],
        phrases: ['落地', '闭环'],
        preference: '简洁、先结论后论据',
      );
      final round = UserProfile.fromMarkdown(p0.toMarkdown());
      expect(round.vocabulary, p0.vocabulary);
      expect(round.phrases, p0.phrases);
      expect(round.preference, p0.preference);
    });

    test('空画像：Markdown 可生成且解析回空', () {
      const empty = UserProfile();
      expect(UserProfile.fromMarkdown(empty.toMarkdown()).isEmpty, isTrue);
    });

    test('容错：列表前缀、额外小节、乱序都不影响解析', () {
      const md = '''
# 我的画像

## 专业词库
- 膜池
* MBR
1. 回款周期

## 别的小节
这段应该被忽略

## 常用表达
落地方案

## 风格偏好
简洁
少形容词
''';
      final p0 = UserProfile.fromMarkdown(md);
      expect(p0.vocabulary, ['膜池', 'MBR', '回款周期']);
      expect(p0.phrases, ['落地方案']);
      expect(p0.preference, '简洁\n少形容词');
    });

    test('坏输入不抛错', () {
      expect(UserProfile.fromMarkdown('').isEmpty, isTrue);
      expect(UserProfile.fromMarkdown('随便写点什么').isEmpty, isTrue);
    });
  });

  group('MemoryStore｜文件读写与快照', () {
    test('首次使用会建好目录并给出 memory.md 模板', () async {
      await MemoryStore.ensureDirsForTest();
      expect(Directory(MemoryFiles.rootDir()).existsSync(), isTrue);
      expect(Directory(MemoryFiles.skillsDir()).existsSync(), isTrue);
      expect(File(MemoryFiles.memoryPath()).existsSync(), isTrue);
      expect(await MemoryStore.loadMemory(), contains('长期记忆'));
    });

    test('保存画像 → 落成 profile.md，可再读回', () async {
      await MemoryStore.saveProfile(
        const UserProfile(vocabulary: ['甲'], phrases: ['乙'], preference: '丙'),
      );
      expect(File(MemoryFiles.profilePath()).existsSync(), isTrue);
      final loaded = await MemoryStore.loadProfile();
      expect(loaded.vocabulary, ['甲']);
      expect(loaded.phrases, ['乙']);
      expect(loaded.preference, '丙');
    });

    test('appendMemory：带时间戳追加，不覆盖已有内容', () async {
      await MemoryStore.saveMemory('# 长期记忆\n\n- 常驻上海\n');
      await MemoryStore.appendMemory(
        '- 客户多在制造业',
        now: DateTime(2026, 9, 21, 18, 30),
      );
      final text = await MemoryStore.loadMemory();
      expect(text, contains('常驻上海'));
      expect(text, contains('2026-09-21 18:30'));
      expect(text, contains('客户多在制造业'));
    });

    test('保存技能手册 → 出现在 loadSkills，且标题用 slug 当文件名', () async {
      await MemoryStore.saveSkill('客户报价流程', '# 客户报价流程\n\n## 步骤\n1. 先确认预算\n');
      final skills = await MemoryStore.loadSkills();
      expect(skills.keys, contains('客户报价流程'));
      expect(skills['客户报价流程'], contains('先确认预算'));
    });

    test('每次写入都留快照，可回滚', () async {
      await MemoryStore.saveMemory('# 一');
      await MemoryStore.saveMemory('# 二');
      final snaps = MemoryStore.listSnapshots();
      expect(snaps, isNotEmpty, reason: '写了两次应至少有一份快照');
      // 回滚到"最近一次写入之前"的那份：即第二次写前的快照（内容是 "# 一"）
      final newest = MemoryStore.listSnapshotsNewestFirst().first;
      final ok = await MemoryStore.restoreSnapshot(newest);
      expect(ok, isTrue);
      expect(await MemoryStore.loadMemory(), contains('# 一'));
    });

    test('快照数量有上限：超过 maxSnapshotsPerFile 会淘汰最旧的', () async {
      for (var i = 0; i < MemoryStore.maxSnapshotsPerFile + 4; i++) {
        await MemoryStore.saveMemory('# 版本 $i');
        // 时间戳是毫秒级，稍等一下保证每份快照名字不同且有序
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final names = MemoryStore.listSnapshots().keys
          .where((n) => n.startsWith('memory.md'))
          .toList();
      expect(
        names.length,
        lessThanOrEqualTo(MemoryStore.maxSnapshotsPerFile),
        reason: '不能无限增长',
      );
    });

    test('删除技能手册会留快照，可找回', () async {
      await MemoryStore.saveSkill('临时手册', '# 临时手册\n内容');
      expect(await MemoryStore.deleteSkill('临时手册'), isTrue);
      expect((await MemoryStore.loadSkills()).containsKey('临时手册'), isFalse);
      expect(MemoryStore.listSnapshots().keys.any((k) => k.contains('临时手册')), isTrue);
    });
  });

  group('MemoryStore｜分层注入', () {
    test('Tier1：画像 + 长期记忆总是注入', () async {
      await MemoryStore.saveProfile(
        const UserProfile(vocabulary: ['膜池'], preference: '简洁'),
      );
      await MemoryStore.saveMemory('- 常驻上海');
      final section = await MemoryStore.buildPromptSection();
      expect(section, contains('膜池'));
      expect(section, contains('简洁'));
      expect(section, contains('常驻上海'));
    });

    test('Tier2：没有 query 时不注入技能手册；命中关键词才注入', () async {
      await MemoryStore.saveSkill('客户报价流程', '# 客户报价流程\n## 步骤\n先确认预算');
      final withoutQuery = await MemoryStore.buildPromptSection();
      expect(withoutQuery.contains('客户报价流程'), isFalse,
          reason: '不相关时不该占用上下文');

      final hit = await MemoryStore.buildPromptSection(query: '帮我走一遍客户报价流程');
      expect(hit, contains('客户报价流程'));
      expect(hit, contains('先确认预算'));
    });

    test('pickRelevantSkills：按标题命中度排序，最多取 2 个', () async {
      await MemoryStore.saveSkill('客户报价流程', '报价步骤');
      await MemoryStore.saveSkill('会议纪要模板', '会议结构');
      await MemoryStore.saveSkill('周报写法', '周报结构');
      final picked = await MemoryStore.pickRelevantSkills('客户报价流程怎么做');
      expect(picked.length, lessThanOrEqualTo(2));
      expect(picked.first.key, '客户报价流程');
    });

    test('注入有上限：超长文件会被截断', () async {
      await MemoryStore.saveMemory('长' * 20000);
      final section = await MemoryStore.buildPromptSection();
      expect(section.length, lessThanOrEqualTo(MemoryFiles.maxInjectedCharsTotal + 200));
      expect(section, contains('已截断'));
    });
  });
}
