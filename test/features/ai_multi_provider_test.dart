import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';
import 'package:moodiary/features/ai/multi_provider.dart';

/// 可编程的假 Provider：可指定失败或成功
class _FakeProvider implements AiProvider {
  final String name;
  final bool failChat;
  final bool failEmbed;

  _FakeProvider({
    required this.name,
    this.failChat = false,
    this.failEmbed = false,
  });

  @override
  bool get isConfigured => true;

  @override
  Stream<AiChunk> streamTemplate({
    required String content,
    required String template,
  }) {
    return failChat
        ? Stream.value(AiChunk.error('$name 不可用'))
        : Stream.fromIterable([
            AiChunk(text: '$name 处理结果'),
            const AiChunk(done: true),
          ]);
  }

  @override
  Stream<AiChunk> streamChat(List<AiChatMessage> messages) {
    return failChat
        ? Stream.value(AiChunk.error('$name 不可用'))
        : Stream.fromIterable([
            AiChunk(text: '$name 回答'),
            const AiChunk(done: true),
          ]);
  }

  @override
  Future<List<double>> embed(String text) async {
    if (failEmbed) throw StateError('$name embedding 失败');
    return [1.0, 0.0];
  }
}

void main() {
  group('AiProviderConfig', () {
    test('toJson/fromJson 往返一致', () {
      final cfg = AiProviderConfig()
        ..id = 'cfg-1'
        ..name = 'DeepSeek'
        ..baseUrl = 'https://api.deepseek.com/v1'
        ..apiKey = 'sk-test'
        ..chatModel = 'deepseek-chat'
        ..embeddingModel = 'text-embedding-3-small'
        ..visionModel = 'gpt-4o'
        ..voiceModel = 'whisper-1'
        ..enabled = true
        ..priority = 2;

      final restored = AiProviderConfig.fromJson(cfg.toJson());

      expect(restored.id, 'cfg-1');
      expect(restored.name, 'DeepSeek');
      expect(restored.chatModel, 'deepseek-chat');
      expect(restored.visionModel, 'gpt-4o');
      expect(restored.priority, 2);
      expect(restored.isConfigured, isTrue);
    });

    test('toAiConfig 转换', () {
      final cfg = AiProviderConfig()
        ..baseUrl = 'https://x/v1'
        ..apiKey = 'k'
        ..chatModel = 'm1'
        ..embeddingModel = 'e1';
      final ai = cfg.toAiConfig();
      expect(ai.baseUrl, 'https://x/v1');
      expect(ai.model, 'm1');
      expect(ai.embeddingModel, 'e1');
    });

    test('clone 深拷贝互不影响', () {
      final cfg = AiProviderConfig()..name = 'A';
      final copy = cfg.clone()..name = 'B';
      expect(cfg.name, 'A');
      expect(copy.name, 'B');
    });
  });

  group('AiProviderStore 纯函数', () {
    test('sortByPriority 升序', () {
      final list = [
        AiProviderConfig()..id = 'a'..priority = 3,
        AiProviderConfig()..id = 'b'..priority = 0,
        AiProviderConfig()..id = 'c'..priority = 1,
      ];
      final sorted = AiProviderStore.sortByPriority(list);
      expect(sorted.map((c) => c.id), ['b', 'c', 'a']);
    });

    test('enabledConfigured 过滤未启用/未配置', () {
      final list = [
        AiProviderConfig()
          ..id = 'a'
          ..enabled = true
          ..baseUrl = 'x'
          ..apiKey = 'k'
          ..priority = 1,
        AiProviderConfig()..id = 'b'..enabled = false..priority = 0,
        AiProviderConfig()..id = 'c'..enabled = true..priority = 2,
      ];
      final active = AiProviderStore.enabledConfigured(list);
      expect(active.map((c) => c.id), ['a']);
    });
  });

  group('MultiProvider 主备切换', () {
    test('主模型失败自动切换备用并附带提示', () async {
      final provider = MultiProvider([
        _FakeProvider(name: '主', failChat: true),
        _FakeProvider(name: '备'),
      ]);

      final chunks = await provider.streamChat(
        const [AiChatMessage(role: 'user', content: 'hi')],
      ).toList();

      final text = chunks.map((c) => c.text).join();
      expect(text, contains('已自动切换到备用模型'));
      expect(text, contains('备 回答'));
      expect(chunks.any((c) => c.error != null), isFalse);
    });

    test('全部失败返回错误', () async {
      final provider = MultiProvider([
        _FakeProvider(name: 'A', failChat: true),
        _FakeProvider(name: 'B', failChat: true),
      ]);
      final chunks = await provider.streamChat(
        const [AiChatMessage(role: 'user', content: 'hi')],
      ).toList();
      expect(chunks.last.error, isNotNull);
      expect(chunks.last.error, contains('B 不可用'));
    });

    test('embed 主失败切备用', () async {
      final provider = MultiProvider([
        _FakeProvider(name: 'A', failEmbed: true),
        _FakeProvider(name: 'B'),
      ]);
      final vector = await provider.embed('测试');
      expect(vector, [1.0, 0.0]);
    });

    test('空列表返回可读错误', () async {
      final provider = MultiProvider([]);
      expect(provider.isConfigured, isFalse);
      final chunks = await provider.streamChat(
        const [AiChatMessage(role: 'user', content: 'hi')],
      ).toList();
      expect(chunks.first.error, contains('模型管理'));
    });
  });
}
