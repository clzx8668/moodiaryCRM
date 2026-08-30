import 'package:flutter/material.dart';

/// 通用两态输入框（详情页常驻 / AI 知识库页 / 快速收集 复用）。
///
/// - 折叠态（默认）：一行，左侧 [大模型选择][@]，中间「按住输入语音」可点按激活 / 长按语音，
///   右侧 [语音/键盘互斥][+]；发送按钮隐藏。
/// - 激活态：两层，上层输入框自动变高，下层功能栏（模型/@/语音/+ + 发送/停止）。
/// - [startActive] = true 时（快速收集）进入即激活态。
class SmartInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool streaming;
  final bool startActive;
  final String collapsedHint;
  final String activeHint;
  final ValueChanged<String> onSend;
  final VoidCallback? onStop;
  final bool voiceMode;
  final VoidCallback? onToggleVoice;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;
  final bool listening;
  final String modelLabel;
  final VoidCallback? onModelSelect;
  final VoidCallback? onAt;
  final VoidCallback? onPlus;

  const SmartInputBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.streaming,
    this.startActive = false,
    this.collapsedHint = '按住输入语音',
    this.activeHint = '输入内容…',
    required this.onSend,
    this.onStop,
    this.voiceMode = false,
    this.onToggleVoice,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onLongPressCancel,
    this.listening = false,
    this.modelLabel = '快速',
    this.onModelSelect,
    this.onAt,
    this.onPlus,
  });

  @override
  State<SmartInputBar> createState() => _SmartInputBarState();
}

class _SmartInputBarState extends State<SmartInputBar>
    with SingleTickerProviderStateMixin {
  late bool _active;
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _active = widget.startActive;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    widget.controller.addListener(_onChanged);
    widget.focusNode?.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SmartInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening && !oldWidget.listening) {
      _pulse.repeat(reverse: true);
    } else if (!widget.listening && oldWidget.listening) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    widget.controller.removeListener(_onChanged);
    widget.focusNode?.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _onFocusChanged() {
    // 非快速收集（resident）：失焦且无输入时收缩回一行
    if (!widget.startActive &&
        !(widget.focusNode?.hasFocus ?? false) &&
        widget.controller.text.trim().isEmpty) {
      setState(() => _active = false);
    }
  }

  void _submit() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return _active ? _buildActive(context) : _buildCollapsed(context);
  }

  Widget _buildCollapsed(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(6, 2, 4, 2),
      child: Row(
        children: [
          // 模型按钮可收缩：模板名较长时避免功能栏右侧溢出
          Flexible(child: _modelButton(context)),
          _roundIcon(Icons.alternate_email_rounded, '知识库', widget.onAt),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() => _active = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.focusNode?.requestFocus();
                });
              },
              onLongPressStart: widget.onLongPressStart == null
                  ? null
                  : (_) => widget.onLongPressStart!(),
              onLongPressEnd: widget.onLongPressEnd == null
                  ? null
                  : (_) => widget.onLongPressEnd!(),
              onLongPressCancel: widget.onLongPressCancel,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.listening)
                      _pulsingMic(colorScheme)
                    else
                      Icon(
                        widget.voiceMode
                            ? Icons.mic_none_rounded
                            : Icons.keyboard_alt_outlined,
                        size: 18,
                        color: colorScheme.outline,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      widget.listening
                          ? '正在聆听…'
                          : (widget.voiceMode ? '按住 说话' : widget.collapsedHint),
                      style: TextStyle(
                        color: widget.listening
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _roundIcon(
            widget.voiceMode
                ? Icons.keyboard_alt_outlined
                : Icons.mic_none_rounded,
            widget.voiceMode ? '切键盘' : '切语音',
            widget.onToggleVoice,
          ),
          _roundIcon(Icons.add_circle_outline_rounded, '添加附件', widget.onPlus,
              iconSize: 26),
        ],
      ),
    );
  }

  Widget _buildActive(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = widget.controller.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.voiceMode
              ? _buildVoiceHold()
              : TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  autofocus: widget.startActive,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: widget.activeHint,
                    isDense: true,
                    border:
                        const OutlineInputBorder(borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左侧区：模型 + @，占满剩余空间（内容靠左），避免右侧三键被推开
            Expanded(
              child: Row(
                children: [
                  // 模型按钮可收缩：模板名较长时避免功能栏右侧溢出
                  Flexible(child: _modelButton(context)),
                  _roundIcon(
                    Icons.alternate_email_rounded,
                    '知识库',
                    widget.onAt,
                  ),
                ],
              ),
            ),
            // 右侧：语音 / 加号 / 发送 固定靠右
            _roundIcon(
              widget.voiceMode
                  ? Icons.keyboard_alt_outlined
                  : Icons.mic_none_rounded,
              widget.voiceMode ? '切键盘' : '切语音',
              widget.onToggleVoice,
            ),
            _roundIcon(Icons.add_circle_outline_rounded, '添加附件', widget.onPlus,
                iconSize: 26),
            const SizedBox(width: 4),
            widget.streaming
                ? IconButton.filled(
                    onPressed: widget.onStop,
                    icon: const Icon(Icons.stop_rounded),
                    tooltip: '停止生成',
                  )
                : IconButton.filled(
                    onPressed: hasText ? _submit : null,
                    icon: const Icon(Icons.arrow_upward_rounded),
                    tooltip: '发送',
                  ),
          ],
        ),
      ],
    );
  }

  Widget _modelButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: '大模型选择',
      padding: EdgeInsets.zero,
      onSelected: (_) => widget.onModelSelect?.call(),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'switch', child: Text('切换模型')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 14, color: colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                widget.modelLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                size: 16, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceHold() {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: widget.onLongPressStart == null
          ? null
          : (_) => widget.onLongPressStart!(),
      onLongPressEnd: widget.onLongPressEnd == null
          ? null
          : (_) => widget.onLongPressEnd!(),
      onLongPressCancel: widget.onLongPressCancel,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.listening)
              _pulsingMic(colorScheme)
            else
              Icon(Icons.mic_none_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              widget.listening ? '正在聆听…' : '按住 说话',
              style: TextStyle(
                color: widget.listening
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pulsingMic(ColorScheme colorScheme) {
    return FadeTransition(
      opacity: _pulseAnim,
      child: ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mic_rounded,
            size: 16,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _roundIcon(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    double iconSize = 20,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: iconSize),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
