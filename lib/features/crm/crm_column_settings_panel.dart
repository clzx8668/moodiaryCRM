import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';

/// 列设置内联面板（Twenty 式设置抽屉，替代弹窗）。
class CrmColumnSettingsPanel extends StatefulWidget {
  final List<LocalObjectField> fields;
  final List<String> allFieldNames;
  final List<String> visible;
  final bool customized;
  final void Function(List<String> visible, bool customized) onSave;
  final VoidCallback onClose;

  const CrmColumnSettingsPanel({
    super.key,
    required this.fields,
    required this.allFieldNames,
    required this.visible,
    required this.customized,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<CrmColumnSettingsPanel> createState() =>
      _CrmColumnSettingsPanelState();
}

class _CrmColumnSettingsPanelState extends State<CrmColumnSettingsPanel> {
  late List<String> _visible = List.of(widget.visible);
  late bool _customized = widget.customized;

  @override
  Widget build(BuildContext context) {
    final hiddenChips = widget.allFieldNames
        .where((f) => !_visible.contains(f))
        .toList();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Text('列设置', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _visible = [
                      for (final f in widget.fields) f.name,
                    ].where(widget.allFieldNames.contains).toList();
                    _customized = false;
                  }),
                  child: const Text('恢复默认'),
                ),
                IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '拖动调整顺序，勾选控制显示',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _visible.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _visible.removeAt(oldIndex);
                  _visible.insert(newIndex, item);
                  _customized = true;
                });
              },
              itemBuilder: (context, index) {
                final field = _visible[index];
                return ListTile(
                  key: ValueKey(field),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle_rounded),
                  ),
                  title: Text(_label(field), style: const TextStyle(fontSize: 13)),
                  trailing: Checkbox(
                    value: true,
                    onChanged: (v) => setState(() {
                      if (v == false) {
                        _visible.remove(field);
                        _customized = true;
                      }
                    }),
                  ),
                );
              },
            ),
          ),
          if (hiddenChips.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '隐藏字段（点击恢复显示）',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final field in hiddenChips)
                        ActionChip(
                          label: Text(
                            _label(field),
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() {
                            _visible.add(field);
                            _customized = true;
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    widget.onSave(_visible, _customized);
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(String name) {
    for (final f in widget.fields) {
      if (f.name == name) return f.label;
    }
    return name;
  }
}
