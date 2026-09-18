import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';

/// 模型名下拉的可选项计算（纯函数，便于单测）。
///
/// 背景（真机 bug）：`DropdownButtonFormField` 有硬断言——`initialValue`
/// 必须**恰好**等于某一项的值，否则直接抛异常（整块渲染成红屏）。而模型名
/// 可能为空、可能是官方列表外的自定义名、服务商返回的列表还可能带重复项，
/// 三种情况都会踩中。这里统一把「可选项」和「安全当前值」算好。
class ModelDropdownModel {
  ModelDropdownModel._();

  /// 「自定义…」哨兵值：允许手动输入官方列表之外的模型名。
  static const String customValue = '__custom__';

  /// 官方模型列表：去空白、去重、保序，并剔除与哨兵冲突的值。
  static List<String> options(List<String> models) {
    final out = <String>[];
    for (final raw in models) {
      final value = raw.trim();
      if (value.isEmpty || value == customValue) continue;
      if (!out.contains(value)) out.add(value);
    }
    return out;
  }

  /// 下拉的全部可选值：官方模型 → 当前值（不在列表时补一条）→ 自定义哨兵。
  static List<String> values({
    required List<String> models,
    required String current,
  }) {
    final out = options(models);
    final cur = current.trim();
    if (cur.isNotEmpty && cur != customValue && !out.contains(cur)) {
      out.add(cur);
    }
    out.add(customValue);
    return out;
  }

  /// 安全的 `initialValue`：为空或不在可选项里时返回 null（下拉显示占位提示）。
  static String? safeValue({
    required String current,
    required List<String> items,
  }) {
    final cur = current.trim();
    if (cur.isEmpty) return null;
    return items.contains(cur) ? cur : null;
  }

  /// 当前值是否属于「官方列表之外的模型名」（用于显示「（自定义）」）。
  static bool isCustom({
    required String current,
    required List<String> models,
  }) {
    final cur = current.trim();
    if (cur.isEmpty || cur == customValue) return false;
    return !options(models).contains(cur);
  }
}

/// 模型名选择：优先下拉已选服务商的可用模型；无模型且未设置时回退手输。
///
/// 注意：本组件**不允许**把空值/非法值直接丢给 `DropdownButton`（会触发断言），
/// 详见 [ModelDropdownModel]。
class AiModelField extends StatefulWidget {
  final List<String> models;
  final String modelName;
  final ValueChanged<String> onChanged;

  const AiModelField({
    super.key,
    required this.models,
    required this.modelName,
    required this.onChanged,
  });

  @override
  State<AiModelField> createState() => _AiModelFieldState();
}

class _AiModelFieldState extends State<AiModelField> {
  /// 用于在「自定义…」被取消后强制重建下拉，避免哨兵值停留在选中态。
  int _epoch = 0;

  @override
  Widget build(BuildContext context) {
    final modelName = widget.modelName.trim();
    final official = ModelDropdownModel.options(widget.models);

    // 官方列表为空且无当前值：给手输框（提示先去拉官方模型列表）
    if (official.isEmpty && modelName.isEmpty) {
      return TextFormField(
        initialValue: modelName,
        decoration: const InputDecoration(
          labelText: '模型名',
          helperText: '该服务商尚未选择模型，可先到「服务商」拉取官方模型列表',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => widget.onChanged(v.trim()),
      );
    }

    final values = ModelDropdownModel.values(
      models: widget.models,
      current: modelName,
    );
    final initial = ModelDropdownModel.safeValue(
      current: modelName,
      items: values,
    );
    final isCustom = ModelDropdownModel.isCustom(
      current: modelName,
      models: widget.models,
    );

    return DropdownButtonFormField<String>(
      key: ValueKey('model-$_epoch-$modelName'),
      initialValue: initial,
      hint: const Text('选择模型…'),
      decoration: const InputDecoration(
        labelText: '模型名',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final value in values)
          DropdownMenuItem(
            value: value,
            child: Text(
              value == ModelDropdownModel.customValue
                  ? '自定义…'
                  : (isCustom && value == modelName ? '$value（自定义）' : value),
            ),
          ),
      ],
      onChanged: (v) async {
        if (v == null) return;
        if (v != ModelDropdownModel.customValue) {
          widget.onChanged(v);
          return;
        }
        final res = await showTextInputDialog(
          context: context,
          title: '自定义模型名',
          textFields: [
            DialogTextField(
              initialText: isCustom ? modelName : '',
              hintText: '如 qwen3-asr-flash / whisper-1',
            ),
          ],
        );
        final typed = res?.first.trim() ?? '';
        if (!mounted) return;
        if (typed.isNotEmpty) {
          widget.onChanged(typed);
        } else {
          setState(() => _epoch++);
        }
      },
    );
  }
}
