import 'package:flutter/material.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 详情页底部常驻追加输入条（Blinko aiInput 式）。
///
/// 支持：文本追加、模板选择（触发 AI 处理）、@ 占位、语音占位（P2.7.6）。
class AppendInputBar extends StatefulWidget {
  final Future<void> Function(String text, String template)? onSend;

  const AppendInputBar({super.key, this.onSend});

  @override
  State<AppendInputBar> createState() => _AppendInputBarState();
}

class _AppendInputBarState extends State<AppendInputBar> {
  final TextEditingController _controller = TextEditingController();
  String _template = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend?.call(text, _template);
      if (mounted) {
        _controller.clear();
        setState(() => _template = '');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = _controller.text.trim().isNotEmpty;

    return Material(
      color: colorScheme.surface,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_template.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text(
                        '模板：${AiTemplates.label(_template)}（发送后 AI 处理）',
                      ),
                      labelStyle: const TextStyle(fontSize: 11),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => setState(() => _template = ''),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _RoundIcon(
                    icon: Icons.mic_none_rounded,
                    tooltip: '语音（开发中）',
                    onTap: () =>
                        toast.info(message: '语音识别接入中，请先用键盘输入'),
                  ),
                  const SizedBox(width: 4),
                  _RoundIcon(
                    icon: Icons.alternate_email_rounded,
                    tooltip: '@ 智能提及（开发中）',
                    onTap: () =>
                        toast.info(message: '@ 智能提及接入中'),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                    tooltip: '选择模板',
                    onSelected: (v) => setState(() => _template = v),
                    itemBuilder: (_) => [
                      for (final t in AiTemplates.all)
                        PopupMenuItem(value: t, child: Text(AiTemplates.label(t))),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: '追加笔记，或选择模板后交给 AI…',
                        isDense: true,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  hasText
                      ? IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 20),
                          tooltip: '追加',
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
    );
  }
}
