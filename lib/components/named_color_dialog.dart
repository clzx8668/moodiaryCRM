import 'package:flutter/material.dart';
import 'package:moodiary/common/values/colors.dart';

/// 名称 + 背景色块 弹窗。
///
/// 返回 `(名称, 颜色ARGB)`；取消返回 `null`。
/// 未选颜色时默认取 [AppColor.themeColorList] 首色，供“不选则默认指派”使用。
Future<(String, int)?> showNamedColorDialog({
  required BuildContext context,
  required String title,
  String nameHint = '',
  String nameLabel = '',
  String initialName = '',
  int? initialColor,
}) async {
  final palette = AppColor.themeColorList;
  final controller = TextEditingController(text: initialName);
  var selectedColor = initialColor ?? palette.first.toARGB32();

  final result = await showDialog<(String, int)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nameLabel.isNotEmpty) ...[
                  Text(
                    nameLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                ],
                TextField(
                  controller: controller,
                  autofocus: initialName.isEmpty,
                  decoration: InputDecoration(
                    hintText: nameHint,
                    isDense: true,
                    border: const UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '背景色',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final color in palette)
                      InkWell(
                        onTap: () {
                          selectedColor = color.toARGB32();
                          setLocalState(() {});
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == color.toARGB32()
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              width: selectedColor == color.toARGB32() ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                Navigator.pop(dialogContext, (name, selectedColor));
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    ),
  );

  controller.dispose();
  return result;
}
