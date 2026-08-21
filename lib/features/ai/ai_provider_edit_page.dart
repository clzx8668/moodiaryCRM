import 'package:flutter/material.dart';
import 'package:moodiary/features/ai/ai_provider_store.dart';
import 'package:moodiary/features/ai/models/ai_provider_config.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 模型配置编辑页（新增 / 编辑单个服务商）。
class AiProviderEditPage extends StatefulWidget {
  final AiProviderConfig? initial;

  const AiProviderEditPage({super.key, this.initial});

  @override
  State<AiProviderEditPage> createState() => _AiProviderEditPageState();
}

class _AiProviderEditPageState extends State<AiProviderEditPage> {
  late final AiProviderConfig _config;
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _chatModel;
  late final TextEditingController _description;
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _config = widget.initial?.clone() ?? AiProviderConfig();
    _name = TextEditingController(text: _config.name);
    _baseUrl = TextEditingController(text: _config.baseUrl);
    _apiKey = TextEditingController(text: _config.apiKey);
    _chatModel = TextEditingController(text: _config.chatModel);
    _description = TextEditingController(text: _config.description);
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    _chatModel.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty ||
        _baseUrl.text.trim().isEmpty ||
        _apiKey.text.trim().isEmpty) {
      toast.info(message: '请填写服务商名称、Base URL 与 API Key');
      return;
    }
    setState(() => _saving = true);
    _config
      ..name = _name.text.trim()
      ..baseUrl = _baseUrl.text.trim()
      ..apiKey = _apiKey.text.trim()
      ..chatModel = _chatModel.text.trim()
      ..description = _description.text.trim();
    await AiProviderStore.upsert(_config);
    toast.success(message: '已保存');
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? '添加模型' : '编辑模型'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '服务商名称',
              hintText: '如 DeepSeek / OpenAI / Kimi / 通义',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'Base URL（OpenAI 兼容）',
              hintText: 'https://api.deepseek.com/v1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          TextField(
            controller: _chatModel,
            decoration: const InputDecoration(
              labelText: '默认对话模型（建议值）',
              hintText: '如 deepseek-chat / gpt-4o / kimi-k2',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: '备注',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _config.enabled,
            onChanged: (v) => setState(() => _config.enabled = v),
            title: const Text('启用该模型'),
            subtitle: const Text('关闭后不参与对话/检索（备用切换也会跳过）'),
          ),
          const SizedBox(height: 8),
          Text(
            '服务商仅管理账号（Base URL / API Key）。具体功能使用的模型请在'
            '「模型管理 → 功能模型」中分别配置（对话/向量/多模态/语音可各自选择服务商）。',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
