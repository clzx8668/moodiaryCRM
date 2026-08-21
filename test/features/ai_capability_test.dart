import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/ai_capability_store.dart';
import 'package:moodiary/features/ai/ai_composite_provider.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/models/ai_capability_config.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';
import 'package:moodiary/features/ai/multi_provider.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AiCapabilitySet', () {
    test('toJson/fromJson 往返一致', () {
      final set = AiCapabilitySet(
        chat: AiCapabilityConfig(
          id: 'chat',
          enabled: true,
          providerId: '',
          modelName: 'deepseek-chat',
        ),
        embedding: AiCapabilityConfig(
          id: 'embedding',
          enabled: true,
          providerId: 'p2',
          modelName: 'text-embedding-3-small',
        ),
        voice: AiCapabilityConfig(
          id: 'voice',
          enabled: false,
          providerId: 'p2',
          modelName: 'whisper-1',
        ),
      );

      final restored = AiCapabilitySet.fromJson(set.toJson());
      expect(restored.chat.enabled, isTrue);
      expect(restored.chat.modelName, 'deepseek-chat');
      expect(restored.embedding.providerId, 'p2');
      expect(restored.embedding.modelName, 'text-embedding-3-small');
      expect(restored.voice.enabled, isFalse);
      expect(restored.vision.enabled, isFalse);
    });
  });

  group('AiCapabilityStore 默认生成（旧配置迁移）', () {
    test('从服务商列表生成默认能力', () async {
      await AiProviderStore.saveAll([
        AiProviderConfig()
          ..id = 'p1'
          ..name = 'DeepSeek'
          ..baseUrl = 'https://a'
          ..apiKey = 'k1'
          ..chatModel = 'deepseek-chat'
          ..enabled = true
          ..priority = 0,
        AiProviderConfig()
          ..id = 'p2'
          ..name = 'OpenAI'
          ..baseUrl = 'https://b'
          ..apiKey = 'k2'
          ..chatModel = 'gpt-4o'
          ..embeddingModel = 'text-embedding-3-small'
          ..visionModel = 'gpt-4o'
          ..voiceModel = 'whisper-1'
          ..enabled = true
          ..priority = 1,
      ]);

      final caps = await AiCapabilityStore.load();

      expect(caps.chat.enabled, isTrue);
      expect(caps.chat.providerId, ''); // 空 = 全部服务商主备
      expect(caps.embedding.enabled, isTrue);
      expect(caps.embedding.providerId, 'p2');
      expect(caps.embedding.modelName, 'text-embedding-3-small');
      expect(caps.vision.providerId, 'p2');
      expect(caps.voice.providerId, 'p2');
    });

    test('无服务商时能力全部未启用', () async {
      final caps = await AiCapabilityStore.load();
      expect(caps.chat.enabled, isFalse);
      expect(caps.embedding.enabled, isFalse);
      expect(caps.vision.enabled, isFalse);
      expect(caps.voice.enabled, isFalse);
    });
  });

  group('AiCompositeProvider', () {
    test('未配置向量模型时 embed 抛友好错误', () async {
      final provider = AiCompositeProvider(chat: MultiProvider([]));
      expect(provider.isConfigured, isFalse);
      expect(
        () => provider.embed('测试'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('向量模型'),
          ),
        ),
      );
    });

    test('fromStore 装配：对话启用 + 向量未启用', () async {
      await AiProviderStore.saveAll([
        AiProviderConfig()
          ..id = 'p1'
          ..name = 'DeepSeek'
          ..baseUrl = 'https://a'
          ..apiKey = 'k1'
          ..chatModel = 'deepseek-chat'
          ..enabled = true
          ..priority = 0,
      ]);
      await AiCapabilityStore.save(
        AiCapabilitySet(
          chat: AiCapabilityConfig(id: 'chat', enabled: true),
          embedding: AiCapabilityConfig(id: 'embedding', enabled: false),
        ),
      );

      final provider = await AiCompositeProvider.fromStore();
      expect(provider.isConfigured, isTrue);
      await expectLater(
        provider.embed('x'),
        throwsA(isA<StateError>()),
      );
    });

    test('指定对话主模型并暴露可用模型列表', () async {
      await AiProviderStore.saveAll([
        AiProviderConfig()
          ..id = 'p1'
          ..name = 'DeepSeek'
          ..baseUrl = 'https://a'
          ..apiKey = 'k1'
          ..models.addAll(['deepseek-chat', 'deepseek-reasoner'])
          ..enabled = true
          ..priority = 0,
        AiProviderConfig()
          ..id = 'p2'
          ..name = 'OpenAI'
          ..baseUrl = 'https://b'
          ..apiKey = 'k2'
          ..models.addAll(['gpt-4o'])
          ..enabled = true
          ..priority = 1,
      ]);
      await AiCapabilityStore.save(
        AiCapabilitySet(
          chat: AiCapabilityConfig(
            id: 'chat',
            enabled: true,
            providerId: 'p1',
            modelName: 'deepseek-reasoner',
          ),
        ),
      );

      final provider = await AiCompositeProvider.fromStore();

      expect(provider.chatLabel, 'DeepSeek · deepseek-reasoner');
      expect(provider.chatModels.length, 3);
      expect(
        provider.chatModels.map((c) => c.label),
        contains('OpenAI · gpt-4o'),
      );
    });
  });
}
