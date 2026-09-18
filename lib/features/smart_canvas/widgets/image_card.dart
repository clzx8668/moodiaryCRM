import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/image_decode_util.dart';

/// 图片卡片：缩略图预览，点击全屏放大。
class ImageCard extends StatelessWidget {
  final String imageName;

  const ImageCard({super.key, required this.imageName});

  @override
  Widget build(BuildContext context) {
    final path = FileUtil.getRealPath('image', imageName);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) => Image.file(
          File(path),
          fit: BoxFit.cover,
          // 卡片宽度受限：按实际可用宽度解码，避免整张手机原图进内存
          cacheWidth: ImageDecodeUtil.cacheWidthFor(
            logicalWidth: constraints.maxWidth,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
          errorBuilder: (_, __, ___) => Container(
            height: 120,
            alignment: Alignment.center,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}
