import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/features/ai/models/ai_chat_session.dart';
import 'package:moodiary/features/block/markdown_projection.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/crm/local/crm_backup_codec.dart';
import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/models/crm_entity_cache.dart';
import 'package:moodiary/features/rag/models/block_embedding.dart';
import 'package:moodiary/features/rag/models/knowledge_base.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:path/path.dart' as p;

/// 同步/备份内容范围：仅笔记（日记+Block+分类）或全部（含 CRM/知识库/会话/AI 配置）
enum BackupScope { notes, all }

extension BackupScopeName on BackupScope {
  String get name => switch (this) {
    BackupScope.notes => 'notes',
    BackupScope.all => 'all',
  };
}

BackupScope backupScopeFromName(String? value) =>
    value == BackupScope.notes.name ? BackupScope.notes : BackupScope.all;

/// P4.4 结构化备份：Markdown + JSON 全量导出/导入（可读、跨端、往返一致）。
///
/// 备份包为 zip：
/// - `manifest.json`：schema 版本 + 导出时间 + 各类计数；
/// - `diaries/<id>.json`：Diary 全字段 + 其全部 Block（含软删墓碑）；
/// - `diaries/<id>.md`：人类可读的 Markdown 投影；
/// - `categories.json`、`crm/<type>/<id>.json`、`knowledge/<id>.json`、
///   `knowledge_embeddings/<block>_<kb>.json`、`ai_sessions/<id>.json`、`ai_messages/<id>.json`。
class BackupService {
  static const int schemaVersion = 1;

  /// 导出全部数据为 zip 备份包；[targetDirectory] 为空时写入缓存目录。
  ///
  /// [extraJson]：附加 JSON 文件（key 为 zip 内文件名，value 可 JSON 编码），
  /// 局域网全量同步用它携带 AI 服务商/能力配置等非数据库数据。
  static Future<File> export({
    String? targetDirectory,
    Map<String, Object>? extraJson,
    BackupScope scope = BackupScope.all,
  }) async {
    final diaries = await IsarUtil.getAllDiaries();
    final blocks = await IsarUtil.getAllBlocks();
    final categories = await IsarUtil.getAllCategoryAsync();
    final crmEntities = await IsarUtil.getAllCrmEntities();
    final crmLocalData = scope == BackupScope.all
        ? await CrmBackupCodec.exportAll(CrmLocalRepository())
        : null;
    final knowledgeBases = await IsarUtil.getAllKnowledgeBases();
    final embeddings = await IsarUtil.getAllBlockEmbeddings();
    final sessions = await IsarUtil.getAllChatSessions();
    final messages = <AiChatMessageRecord>[
      for (final session in sessions)
        ...await IsarUtil.getChatMessages(session.id),
    ];

    final archive = Archive();
    void addJson(String name, Object data) {
      archive.addFile(ArchiveFile.string(name, jsonEncode(data)));
    }

    addJson(
      'manifest.json',
      {
        'schemaVersion': schemaVersion,
        'app': 'moodiaryCRM',
        'exportedAt': DateTime.now().toIso8601String(),
        'counts': {
          'diaries': diaries.length,
          'blocks': blocks.length,
          'categories': categories.length,
          'crm': scope == BackupScope.all ? crmEntities.length : 0,
          'crmLocal': crmLocalData?.length ?? 0,
          'knowledgeBases':
              scope == BackupScope.all ? knowledgeBases.length : 0,
          'embeddings': scope == BackupScope.all ? embeddings.length : 0,
          'sessions': scope == BackupScope.all ? sessions.length : 0,
          'messages': scope == BackupScope.all ? messages.length : 0,
        },
      },
    );

    final blocksByDiary = <String, List<Block>>{};
    for (final block in blocks) {
      blocksByDiary.putIfAbsent(block.diaryId, () => []).add(block);
    }
    for (final diary in diaries) {
      final diaryBlocks = blocksByDiary[diary.id] ?? [];
      addJson(
        'diaries/${diary.id}.json',
        {
          'diary': diary.toJson(),
          'blocks': [for (final b in diaryBlocks) b.toJson()],
        },
      );
      final markdown = MarkdownProjection.aggregate(diaryBlocks);
      archive.addFile(
        ArchiveFile.string(
          'diaries/${diary.id}.md',
          _diaryMarkdown(diary, markdown),
        ),
      );
    }

    addJson('categories.json', [for (final c in categories) c.toJson()]);

    if (scope == BackupScope.all) {
      if (crmLocalData != null) {
        addJson('crm_local.json', crmLocalData);
      }
      for (final entity in crmEntities) {
        addJson('crm/${entity.entityType}/${entity.id}.json', entity.toJson());
      }
      for (final kb in knowledgeBases) {
        addJson('knowledge/${kb.id}.json', kb.toJson());
      }
      for (final embedding in embeddings) {
        addJson(
          'knowledge_embeddings/${embedding.blockId}_${embedding.knowledgeBaseId}.json',
          {
            'blockId': embedding.blockId,
            'diaryId': embedding.diaryId,
            'knowledgeBaseId': embedding.knowledgeBaseId,
            'text': embedding.text,
            'dimension': embedding.dimension,
            'embedding': embedding.encode(),
            'updatedAt': embedding.updatedAt.toIso8601String(),
          },
        );
      }
      for (final session in sessions) {
        addJson(
          'ai_sessions/${session.id}.json',
          {
            'id': session.id,
            'title': session.title,
            'createdAt': session.createdAt.toIso8601String(),
            'updatedAt': session.updatedAt.toIso8601String(),
          },
        );
      }
      for (final message in messages) {
        addJson(
          'ai_messages/${message.id}.json',
          {
            'id': message.id,
            'sessionId': message.sessionId,
            'role': message.role,
            'content': message.content,
            'sources': message.sourcesJson,
            'createdAt': message.createdAt.toIso8601String(),
          },
        );
      }
      for (final entry in (extraJson ?? const <String, Object>{}).entries) {
        addJson(entry.key, entry.value);
      }
    }

    final bytes = ZipEncoder().encode(archive);
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '').split('.').first;
    final directory =
        targetDirectory ?? p.join(FileUtil.getCachePath(''), 'backup');
    await Directory(directory).create(recursive: true);
    final file = File(p.join(directory, 'moodiary_backup_$timestamp.zip'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// 从 zip 备份包导入（按 id 幂等 upsert；备份 schema 过新时抛错）。
  static Future<BackupResult> importFromFile(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, ArchiveFile>{
      for (final f in archive.files)
        if (f.isFile) f.name: f,
    };

    String readJson(String name) {
      final file = files[name];
      if (file == null) throw StateError('备份包缺少文件：$name');
      return _contentToString(file);
    }

    final manifest =
        jsonDecode(readJson('manifest.json')) as Map<String, dynamic>;
    final backupVersion = (manifest['schemaVersion'] as num?)?.toInt() ?? 0;
    if (backupVersion > schemaVersion) {
      throw StateError(
        '备份版本过新（v$backupVersion），请先升级应用再导入',
      );
    }

    var categories = 0;
    var diaries = 0;
    var blocks = 0;
    var crm = 0;
    var crmLocal = 0;
    var knowledgeBases = 0;
    var embeddings = 0;
    var sessions = 0;
    var messages = 0;
    final extras = <String, dynamic>{};

    final categoryList = jsonDecode(readJson('categories.json')) as List;
    for (final raw in categoryList) {
      await IsarUtil.insertACategory(
        Category.fromJson(raw as Map<String, dynamic>),
      );
      categories++;
    }

    for (final entry in files.entries) {
      final name = entry.key;
      if (name.startsWith('diaries/') && name.endsWith('.json')) {
        final data =
            jsonDecode(_contentToString(entry.value)) as Map<String, dynamic>;
        final diary = Diary.fromJson(data['diary'] as Map<String, dynamic>);
        await IsarUtil.insertADiary(diary);
        diaries++;
        for (final raw in (data['blocks'] as List? ?? const [])) {
          await IsarUtil.insertBlock(
            Block.fromJson(raw as Map<String, dynamic>),
          );
          blocks++;
        }
      } else if (name == 'crm_local.json') {
        final data =
            jsonDecode(_contentToString(entry.value)) as Map<String, dynamic>;
        await CrmBackupCodec.importAll(CrmLocalRepository(), data);
        crmLocal++;
      } else if (name.startsWith('crm/') && name.endsWith('.json')) {
        await IsarUtil.upsertCrmEntities([
          CrmEntityCache.fromJson(
            jsonDecode(_contentToString(entry.value)) as Map<String, dynamic>,
          ),
        ]);
        crm++;
      } else if (name.startsWith('knowledge/') && name.endsWith('.json')) {
        await IsarUtil.upsertKnowledgeBase(
          KnowledgeBase.fromJson(
            jsonDecode(_contentToString(entry.value)) as Map<String, dynamic>,
          ),
        );
        knowledgeBases++;
      } else if (name.startsWith('knowledge_embeddings/') &&
          name.endsWith('.json')) {
        final data =
            jsonDecode(_contentToString(entry.value)) as Map<String, dynamic>;
        final embedding = BlockEmbedding()
          ..blockId = data['blockId'] as String
          ..diaryId = data['diaryId'] as String? ?? ''
          ..knowledgeBaseId = data['knowledgeBaseId'] as String
          ..text = data['text'] as String? ?? ''
          ..embedding = BlockEmbedding.decode(
            data['embedding'] as String? ?? '',
            (data['dimension'] as num?)?.toInt() ?? 0,
          )
          ..updatedAt = DateTime.parse(data['updatedAt'] as String);
        await IsarUtil.upsertBlockEmbedding(embedding);
        embeddings++;
      } else if (name.startsWith('ai_sessions/') && name.endsWith('.json')) {
        final data =
            jsonDecode(_contentToString(entry.value)) as Map<String, dynamic>;
        final session = AiChatSession()
          ..id = data['id'] as String
          ..title = data['title'] as String? ?? '新话题'
          ..createdAt = DateTime.parse(data['createdAt'] as String)
          ..updatedAt = DateTime.parse(data['updatedAt'] as String);
        await IsarUtil.upsertChatSession(session);
        sessions++;
      } else if (name.startsWith('ai_messages/') && name.endsWith('.json')) {
        final data =
            jsonDecode(_contentToString(entry.value)) as Map<String, dynamic>;
        final message = AiChatMessageRecord()
          ..id = data['id'] as String
          ..sessionId = data['sessionId'] as String
          ..role = data['role'] as String? ?? 'user'
          ..content = data['content'] as String? ?? ''
          ..createdAt = DateTime.parse(data['createdAt'] as String);
        message.setSourcesJson(data['sources'] as String? ?? '[]');
        await IsarUtil.insertChatMessage(message);
        messages++;
      } else if (name.endsWith('.json') &&
          name != 'manifest.json' &&
          name != 'categories.json' &&
          !name.startsWith('diaries/') &&
          !name.startsWith('crm/') &&
          !name.startsWith('knowledge/') &&
          !name.startsWith('knowledge_embeddings/') &&
          !name.startsWith('ai_sessions/') &&
          !name.startsWith('ai_messages/')) {
        // 附加 JSON（如 ai_providers.json / ai_capabilities.json），原样带回
        extras[name] = jsonDecode(_contentToString(entry.value));
      }
    }

    return BackupResult(
      categories: categories,
      diaries: diaries,
      blocks: blocks,
      crm: crm,
      crmLocal: crmLocal,
      knowledgeBases: knowledgeBases,
      embeddings: embeddings,
      sessions: sessions,
      messages: messages,
      extras: extras,
    );
  }

  static String _diaryMarkdown(Diary diary, String blocksMarkdown) {
    final buffer = StringBuffer();
    if (diary.title.trim().isNotEmpty) {
      buffer.writeln('# ${diary.title.trim()}');
      buffer.writeln();
    }
    buffer.writeln(
      '> ${diary.time.toLocal().toIso8601String()}'
      '${diary.tags.isNotEmpty ? ' · ${diary.tags.join(', ')}' : ''}',
    );
    buffer.writeln();
    if (blocksMarkdown.trim().isNotEmpty) {
      buffer.writeln(blocksMarkdown.trim());
    } else {
      buffer.writeln(diary.content.trim());
    }
    return buffer.toString();
  }

  static String _contentToString(ArchiveFile file) {
    return utf8.decode(file.content);
  }
}

/// 导入结果统计（用于成功提示与测试断言）
class BackupResult {
  final int categories;
  final int diaries;
  final int blocks;
  final int crm;
  final int crmLocal;
  final int knowledgeBases;
  final int embeddings;
  final int sessions;
  final int messages;
  final Map<String, dynamic> extras;

  const BackupResult({
    this.categories = 0,
    this.diaries = 0,
    this.blocks = 0,
    this.crm = 0,
    this.crmLocal = 0,
    this.knowledgeBases = 0,
    this.embeddings = 0,
    this.sessions = 0,
    this.messages = 0,
    this.extras = const {},
  });

  int get total =>
      categories +
      diaries +
      blocks +
      crm +
      knowledgeBases +
      embeddings +
      sessions +
      messages;

  String get summary =>
      '日记 $diaries / Block $blocks / 分类 $categories / CRM $crm / '
      '知识库 $knowledgeBases / 向量 $embeddings / 会话 $sessions / 消息 $messages';
}
