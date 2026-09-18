import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/utils/image_decode_util.dart';

void main() {
  group('缩略图解码宽度', () {
    test('按逻辑宽度 × 设备像素比计算', () {
      expect(
        ImageDecodeUtil.cacheWidthFor(logicalWidth: 360, devicePixelRatio: 3),
        1080,
      );
      expect(
        ImageDecodeUtil.cacheWidthFor(logicalWidth: 200, devicePixelRatio: 2),
        400,
      );
    });

    test('超过上限时截断（手机原图不再整张解码）', () {
      expect(
        ImageDecodeUtil.cacheWidthFor(logicalWidth: 1440, devicePixelRatio: 3),
        ImageDecodeUtil.defaultMaxWidth,
      );
      expect(
        ImageDecodeUtil.cacheWidthFor(
          logicalWidth: 800,
          devicePixelRatio: 2,
          maxWidth: 720,
        ),
        720,
      );
    });

    test('低于最小宽度时抬到下限，避免小图被放大', () {
      expect(
        ImageDecodeUtil.cacheWidthFor(logicalWidth: 10, devicePixelRatio: 1),
        ImageDecodeUtil.minWidth,
      );
    });

    test('未知/非法尺寸不限制（返回 null 保持原行为）', () {
      expect(
        ImageDecodeUtil.cacheWidthFor(logicalWidth: 0, devicePixelRatio: 3),
        isNull,
      );
      expect(
        ImageDecodeUtil.cacheWidthFor(logicalWidth: -1, devicePixelRatio: 3),
        isNull,
      );
      expect(
        ImageDecodeUtil.cacheWidthFor(
          logicalWidth: double.infinity,
          devicePixelRatio: 3,
        ),
        isNull,
      );
      expect(
        ImageDecodeUtil.cacheWidthFor(
          logicalWidth: 300,
          devicePixelRatio: 3,
          maxWidth: 0,
        ),
        isNull,
      );
    });

    test('设备像素比非法时按 1.0 兜底', () {
      expect(
        ImageDecodeUtil.cacheWidthFor(logicalWidth: 320, devicePixelRatio: 0),
        320,
      );
      expect(
        ImageDecodeUtil.cacheWidthFor(logicalWidth: 320, devicePixelRatio: -2),
        320,
      );
    });

    test('固定尺寸缩略图（附件格）走更小的上限', () {
      expect(
        ImageDecodeUtil.thumbnailWidth(logicalSize: 64, devicePixelRatio: 3),
        192,
      );
      expect(
        ImageDecodeUtil.thumbnailWidth(logicalSize: 64, devicePixelRatio: 8),
        320,
      );
    });
  });
}
