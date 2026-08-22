import 'dart:convert';

import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/rag/rag_service.dart';
import 'package:uuid/uuid.dart';

/// AI 对话会话（历史话题）
class AiChatSession {
  String id = const Uuid().v7();

  String title = '新话题';

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();

  AiChatSession();
}

/// AI 对话消息（含引用来源）
class AiChatMessageRecord {
  String id = const Uuid().v7();

  String sessionId = '';

  String role = 'user'; // user / assistant

  String content = '';

  List<RagHit> sources = const [];

  DateTime createdAt = DateTime.now();

  AiChatMessageRecord();

  AiChatMessage toAiChatMessage() =>
      AiChatMessage(role: role, content: content);

  String get sourcesJson => jsonEncode(
        sources
            .map(
              (s) => {
                'blockId': s.blockId,
                'diaryId': s.diaryId,
                'knowledgeBaseId': s.knowledgeBaseId,
                'text': s.text,
                'score': s.score,
              },
            )
            .toList(),
      );

  void setSourcesJson(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        sources = list.map((e) {
          final m = e as Map<String, dynamic>;
          return RagHit(
            blockId: m['blockId'] as String? ?? '',
            diaryId: m['diaryId'] as String? ?? '',
            knowledgeBaseId: m['knowledgeBaseId'] as String? ?? '',
            text: m['text'] as String? ?? '',
            score: (m['score'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
      }
    } catch (_) {
      sources = [];
    }
  }
}
