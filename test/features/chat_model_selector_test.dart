import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/ai_capability_store.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/chat_model_selector.dart';
import 'package:moodiary/features/ai/models/ai_capability_config.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  AiProviderConfig provider({
    required String id,
    required String name,
    List<String> models = const [],
    String chatModel = '',
    bool enabled = true,
    int priority = 0,
  }) => AiProviderConfig()
    ..id = id
    ..name = name
    ..baseUrl = 'https://api.example.com/v1'
    ..apiKey = 'sk-test'
    ..models = List<String>.from(models)
    ..chatModel = chatModel
    ..enabled = enabled
    ..priority = priority;

  group('可选项与当前值', () {
    test('默认档永远在第一位，且各服务商模型按优先级展开、去重', () {
      final providers = [
        provider(
          id: 'p2',
          name: '硅基流动',
          models: ['Qwen/Qwen3-8B', 'Qwen/Qwen3-8B'],
          priority: 1,
        ),
        provider(
          id: 'p1',
          name: 'DeepSeek',
          models: ['deepseek-flash', 'deepseek-v4-pro'],
          priority: 0,
        ),
      ];
      final options = ChatModelSelector.options(
        providers: providers,
        chat: AiCapabilityConfig(id: 'chat'),
      );

      expect(options.first.isDefault, isTrue);
      expect(options.first.label, '默认（主备自动切换）');
      // 优先级的服务商排前面；重复模型只出现一次
      expect(options.skip(1).map((o) => o.label), [
        'DeepSeek · deepseek-flash',
        'DeepSeek · deepseek-v4-pro',
        '硅基流动 · Qwen/Qwen3-8B',
      ]);
    });

    test('未启用 / 未配置的服务商不出现；models 为空时退回服务商默认对话模型', () {
      final providers = [
        provider(id: 'p1', name: 'A', chatModel: 'a-chat'),
        provider(id: 'p2', name: 'B', models: ['b-1'], enabled: false),
        AiProviderConfig()
          ..id = 'p3'
          ..name = 'C'
          ..baseUrl = ''
          ..apiKey = ''
          ..enabled = true,
      ];
      final options = ChatModelSelector.options(
        providers: providers,
        chat: AiCapabilityConfig(id: 'chat'),
      );
      expect(options.map((o) => o.label), ['默认（主备自动切换）', 'A · a-chat']);
    });

    test('current：空 providerId → 默认档；指定服务商 → 对应模型（modelName 空时用默认对话模型）', () {
      final providers = [
        provider(id: 'p1', name: 'DeepSeek', chatModel: 'deepseek-flash'),
      ];

      expect(
        ChatModelSelector.current(
          providers: providers,
          chat: AiCapabilityConfig(id: 'chat'),
        ).isDefault,
        isTrue,
      );
      expect(
        ChatModelSelector.current(
          providers: providers,
          chat: AiCapabilityConfig(
            id: 'chat',
            providerId: 'p1',
            modelName: 'deepseek-v4-pro',
          ),
        ).label,
        'DeepSeek · deepseek-v4-pro',
      );
      expect(
        ChatModelSelector.current(
          providers: providers,
          chat: AiCapabilityConfig(id: 'chat', providerId: 'p1'),
        ).label,
        'DeepSeek · deepseek-flash',
      );
      // 配置里指的服务商已被删掉 → 兜底成默认档，避免出现"幽灵模型"
      expect(
        ChatModelSelector.current(
          providers: providers,
          chat: AiCapabilityConfig(id: 'chat', providerId: 'gone'),
        ).isDefault,
        isTrue,
      );
    });

    test('excludeModels：被向量/语音/多模态占用的模型不作为对话候选', () {
      final providers = [
        provider(
          id: 'p1',
          name: '硅基流动',
          models: [
            'BAAI/bge-m3',
            'FunAudioLLM/SenseVoiceSmall',
            'Qwen/Qwen3-8B',
          ],
        ),
      ];
      final options = ChatModelSelector.options(
        providers: providers,
        chat: AiCapabilityConfig(id: 'chat'),
        excludeModels: {'BAAI/bge-m3', 'FunAudioLLM/SenseVoiceSmall'},
      );
      expect(options.map((o) => o.label), [
        '默认（主备自动切换）',
        '硅基流动 · Qwen/Qwen3-8B',
      ]);
    });

    test('非对话模型（向量/ASR/重排）即便被勾选也不进候选；正常对话模型保留', () {
      expect(ChatModelSelector.looksLikeNonChatModel('BAAI/bge-m3'), isTrue);
      expect(
        ChatModelSelector.looksLikeNonChatModel('qwen3-asr-flash-realtime'),
        isTrue,
      );
      expect(ChatModelSelector.looksLikeNonChatModel('Qwen/Qwen3-8B'), isFalse);
      expect(
        ChatModelSelector.looksLikeNonChatModel('deepseek-v4-pro'),
        isFalse,
      );
      expect(
        ChatModelSelector.options(
          providers: [
            provider(
              id: 'p1',
              name: 'Qwen',
              models: [
                'qwen3.8-max-0902',
                'qwen3-asr-flash-realtime-2',
                'Qwen/Qwen3-8B',
              ],
            ),
          ],
          chat: AiCapabilityConfig(id: 'chat'),
        ).map((o) => o.label),
        ['默认（主备自动切换）', 'Qwen · qwen3.8-max-0902', 'Qwen · Qwen/Qwen3-8B'],
      );
    });

    test('短标签：默认 / 取模型名末段 / 无模型名用服务商名', () {
      expect(
        const ChatModelSelection(
          providerId: '',
          providerName: '',
          modelName: '',
        ).shortLabel,
        '默认',
      );
      expect(
        const ChatModelSelection(
          providerId: 'p1',
          providerName: '硅基流动',
          modelName: 'Qwen/Qwen3-8B',
        ).shortLabel,
        'Qwen3-8B',
      );
      expect(
        const ChatModelSelection(
          providerId: 'p2',
          providerName: 'DeepSeek',
          modelName: '',
        ).shortLabel,
        'DeepSeek',
      );
    });
  });

  group('切换生效（写回对话能力配置）', () {
    test('选具体模型：providerId/modelName 落库并自动开启对话能力', () async {
      await AiCapabilityStore.save(
        AiCapabilitySet(chat: AiCapabilityConfig(id: 'chat', enabled: false)),
      );

      await ChatModelSelector.apply(
        const ChatModelSelection(
          providerId: 'p1',
          providerName: 'DeepSeek',
          modelName: 'deepseek-v4-pro',
        ),
      );

      final caps = await AiCapabilityStore.load();
      expect(caps.chat.providerId, 'p1');
      expect(caps.chat.modelName, 'deepseek-v4-pro');
      expect(caps.chat.enabled, isTrue);
    });

    test('选默认档：清空 providerId/modelName（回到主备自动切换）', () async {
      await AiCapabilityStore.save(
        AiCapabilitySet(
          chat: AiCapabilityConfig(
            id: 'chat',
            enabled: true,
            providerId: 'p1',
            modelName: 'deepseek-flash',
          ),
        ),
      );

      await ChatModelSelector.apply(
        const ChatModelSelection(
          providerId: ChatModelSelection.defaultProviderId,
          providerName: '',
          modelName: '',
        ),
      );

      final caps = await AiCapabilityStore.load();
      expect(caps.chat.providerId, isEmpty);
      expect(caps.chat.modelName, isEmpty);
    });

    test('currentShortLabel：与存储里的当前选择一致（输入条 chip 用）', () async {
      await AiProviderStore.saveAll([
        provider(
          id: 'p1',
          name: 'DeepSeek',
          models: ['deepseek-flash'],
          chatModel: 'deepseek-flash',
        ),
      ]);
      await AiCapabilityStore.save(
        AiCapabilitySet(
          chat: AiCapabilityConfig(
            id: 'chat',
            enabled: true,
            providerId: 'p1',
            modelName: 'deepseek-flash',
          ),
        ),
      );

      expect(await ChatModelSelector.currentShortLabel(), 'deepseek-flash');
    });
  });
}
