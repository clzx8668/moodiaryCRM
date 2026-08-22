import 'dart:async';

import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';

/// 多平台 Provider：按优先级依次尝试，主模型失败自动切换到备用。
///
/// 切换触发条件：首个输出前返回错误 / 抛异常 / 超时 / 空响应
/// （避免中途切换打断已生成的文本）。
class MultiProvider implements AiProvider {
  final List<_ProviderEntry> _entries;

  /// 首个输出前的等待超时（无首字即判失败切换）
  final Duration firstChunkTimeout;

  MultiProvider(
    List<AiProvider> providers, {
    List<String>? names,
    this.firstChunkTimeout = const Duration(seconds: 30),
  })
    : _entries = [
        for (var i = 0; i < providers.length; i++)
          _ProviderEntry(
            name: names != null && i < names.length
                ? names[i]
                : '模型 ${i + 1}',
            provider: providers[i],
          ),
      ];

  factory MultiProvider.fromConfigs(List<AiProviderConfig> configs) {
    final entries = AiProviderStore.enabledConfigured(configs);
    return MultiProvider([
      for (final c in entries) OpenAiCompatibleProvider(config: c.toAiConfig()),
    ]);
  }

  @override
  bool get isConfigured => _entries.any((e) => e.provider.isConfigured);

  bool get isEmpty => _entries.isEmpty;

  @override
  Stream<AiChunk> streamTemplate({
    required String content,
    required String template,
  }) {
    return _withFailover(
      (p) => p.streamTemplate(content: content, template: template),
    );
  }

  @override
  Stream<AiChunk> streamChat(List<AiChatMessage> messages) {
    return _withFailover((p) => p.streamChat(messages));
  }

  /// 按顺序尝试；首个输出前失败才切换
  Stream<AiChunk> _withFailover(
    Stream<AiChunk> Function(AiProvider p) call,
  ) async* {
    if (_entries.isEmpty) {
      yield AiChunk.error('未配置可用模型，请到「模型管理」添加并启用');
      return;
    }
    String? lastError;
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      var sawContent = false;
      String? failReason;
      final iterator = StreamIterator(call(entry.provider));
      try {
        var hasNext = await iterator.moveNext().timeout(firstChunkTimeout);
        if (!hasNext) {
          failReason = '无响应（空流）';
        }
        while (hasNext) {
          final chunk = iterator.current;
          if (chunk.error != null && !sawContent) {
            failReason = chunk.error;
            break;
          }
          if (chunk.text.isNotEmpty) sawContent = true;
          yield chunk;
          if (chunk.done) break;
          hasNext = await iterator.moveNext();
        }
        if (failReason == null && !sawContent) {
          failReason = '无输出内容';
        }
      } catch (e) {
        if (sawContent) {
          yield AiChunk.error('生成中断：$e');
          return;
        }
        failReason ??= '$e';
      } finally {
        iterator.cancel();
      }
      if (failReason != null) {
        lastError = failReason;
        if (i < _entries.length - 1) {
          yield AiChunk(
            text:
                '\n\n> ⚠️ ${entry.name} 不可用（$failReason），已自动切换到备用模型。\n',
          );
        }
      } else {
        return;
      }
    }
    yield AiChunk.error(lastError ?? '所有模型均不可用');
  }

  @override
  Future<List<double>> embed(String text) async {
    if (_entries.isEmpty) {
      throw StateError('未配置可用模型，请到「模型管理」添加并启用');
    }
    String? lastError;
    for (final entry in _entries) {
      try {
        return await entry.provider.embed(text);
      } catch (e) {
        lastError = '$e';
      }
    }
    throw StateError('所有模型的 Embedding 均失败：$lastError');
  }
}

class _ProviderEntry {
  final String name;
  final AiProvider provider;

  const _ProviderEntry({required this.name, required this.provider});
}
