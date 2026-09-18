/// 图片解码尺寸计算（纯函数，便于单测）。
///
/// 背景（批次 90 手机端细节）：`Image.file` 默认按原图分辨率解码——
/// 手机拍摄的 12MP 照片解码后约 48MB 位图，缩略图/卡片铺满屏幕时极易造成
/// 滚动掉帧甚至 OOM。这里按「逻辑宽度 × 设备像素比」给出 `cacheWidth`，
/// 在保证显示清晰度的前提下把解码内存压到实际需要的量级。
class ImageDecodeUtil {
  ImageDecodeUtil._();

  /// 缩略图解码宽度的默认上限（px）。取 1080 覆盖主流手机整屏宽度。
  static const int defaultMaxWidth = 1080;

  /// 低于该宽度不再限制（避免小图被放大解码）。
  static const int minWidth = 64;

  /// 按显示尺寸计算解码宽度；返回 `null` 表示不限制（保持原图）。
  ///
  /// - [logicalWidth] 显示区域逻辑宽度（≤0 视为未知 → 不限制）；
  /// - [devicePixelRatio] 设备像素比（≤0 视为未知 → 用 1.0）；
  /// - [maxWidth] 解码上限，超过则截断。
  static int? cacheWidthFor({
    required double logicalWidth,
    required double devicePixelRatio,
    int maxWidth = defaultMaxWidth,
  }) {
    if (logicalWidth <= 0 || !logicalWidth.isFinite || maxWidth <= 0) {
      return null;
    }
    final ratio = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
    final raw = (logicalWidth * ratio).round();
    if (raw <= 0) return null;
    if (raw < minWidth) return minWidth;
    return raw > maxWidth ? maxWidth : raw;
  }

  /// 固定尺寸缩略图（如 64×64 附件格）的解码宽度。
  static int thumbnailWidth({
    required double logicalSize,
    required double devicePixelRatio,
    int maxWidth = 320,
  }) {
    return cacheWidthFor(
      logicalWidth: logicalSize,
      devicePixelRatio: devicePixelRatio,
      maxWidth: maxWidth,
    )!;
  }
}
