import 'package:moodiary/persistence/isar.dart';

/// 数据健康度统计（P4.3）：概览计数 + 数据库大小
class HealthStats {
  final int diaries;
  final int blocks;
  final int crmEntities;
  final int knowledgeBases;
  final int embeddings;
  final String dbSizeText;

  const HealthStats({
    required this.diaries,
    required this.blocks,
    required this.crmEntities,
    required this.knowledgeBases,
    required this.embeddings,
    required this.dbSizeText,
  });
}

class HealthService {
  static Future<HealthStats> loadStats() async {
    final diaries = (await IsarUtil.getAllDiaries()).length;
    final blocks = (await IsarUtil.getAllBlocks()).length;
    final crm = (await IsarUtil.getAllCrmEntities()).length;
    final knowledgeBases = (await IsarUtil.getAllKnowledgeBases()).length;
    final embeddings = (await IsarUtil.getAllBlockEmbeddings()).length;
    final size = await IsarUtil.getSize();
    return HealthStats(
      diaries: diaries,
      blocks: blocks,
      crmEntities: crm,
      knowledgeBases: knowledgeBases,
      embeddings: embeddings,
      dbSizeText: '${size['size']}${size['unit']}',
    );
  }
}
