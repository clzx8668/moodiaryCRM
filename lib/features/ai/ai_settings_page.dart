import 'package:flutter/material.dart';
import 'package:moodiary/features/ai/ai_config.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/utils/notice_util.dart';

/// AI 设置页：API 配置 + 连接测试。
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  late final TextEditingController _embeddingModel;
  bool _obscureKey = true;
  bool _testing = false;
  AiConnectionResult? _testResult;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController();
    _apiKey = TextEditingController();
    _model = TextEditingController();
    _embeddingModel = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final config = await AiConfig.load();
    if (!mounted) return;
    _baseUrl.text = config.baseUrl;
    _apiKey.text = config.apiKey;
    _model.text = config.model;
    _embeddingModel.text = config.embeddingModel;
    setState(() {});
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _embeddingModel.dispose();
    super.dispose();
  }

  AiConfig _config() {
    return AiConfig(
      baseUrl: _baseUrl.text.trim(),
      apiKey: _apiKey.text.trim(),
      model: _model.text.trim().isEmpty
          ? AiConfig.defaultModel
          : _model.text.trim(),
      embeddingModel: _embeddingModel.text.trim().isEmpty
          ? AiConfig.defaultEmbeddingModel
          : _embeddingModel.text.trim(),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final result = await AiConnectionTester.test(_config());
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = result;
      });
    }
  }

  Future<void> _save() async {
    final config = _config();
    if (config.baseUrl.isEmpty || config.apiKey.isEmpty) {
      toast.info(message: '请填写 Base URL 与 API Key');
      return;
    }
    await AiConfig.save(
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
      model: config.model,
      embeddingModel: config.embeddingModel,
    );
    toast.success(message: 'AI 配置已保存');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 设置'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'Base URL（OpenAI 兼容）',
              hintText: 'https://api.deepseek.com/v1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKey,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
                icon: Icon(
                  _obscureKey ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: '对话模型',
              hintText: 'deepseek-chat',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _embeddingModel,
            decoration: const InputDecoration(
              labelText: 'Embedding 模型（知识库用）',
              hintText: 'text-embedding-3-small',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '提示：DeepSeek 暂未提供 embeddings 接口；'
            '知识库检索需搭配支持 embeddings 的 OpenAI 兼容服务（如 OpenAI 官方）。',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.wifi_tethering_rounded),
            label: Text(_testing ? '测试中…' : '测试连接'),
          ),
          if (_testResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                color: _testResult!.ok
                    ? colorScheme.primaryContainer
                    : colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _testResult!.ok
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        color: _testResult!.ok
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!.message,
                          style: TextStyle(
                            color: _testResult!.ok
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            '密钥仅保存在本机安全存储（flutter_secure_storage），不会上传。'
            'DeepSeek 默认 Base URL 为 https://api.deepseek.com/v1。',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
