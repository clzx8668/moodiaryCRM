import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary/utils/file_util.dart';

/// 图片卡片：缩略图预览，点击全屏放大。
class ImageCard extends StatelessWidget {
  final String imageName;

  const ImageCard({super.key, required this.imageName});

  @override
  Widget build(BuildContext context) {
    final path = FileUtil.getRealPath('image', imageName);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 120,
          alignment: Alignment.center,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}
