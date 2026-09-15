import 'package:flutter/material.dart';

/// 详情页加载骨架：一条元信息 + 三张卡片轮廓，轻微呼吸动画。
///
/// 比「居中转圈」更安静：页面结构先到位，内容到了再替换，视觉不跳。
class CanvasSkeleton extends StatefulWidget {
  const CanvasSkeleton({super.key, this.padding = 16});

  final double padding;

  @override
  State<CanvasSkeleton> createState() => _CanvasSkeletonState();
}

class _CanvasSkeletonState extends State<CanvasSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget block(double height, {double? width, double radius = 10}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        // 0.55 → 0.95 之间呼吸，避免闪烁感
        opacity: 0.55 + _controller.value * 0.4,
        child: child,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.padding,
          8,
          widget.padding,
          widget.padding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            block(14, width: 160),
            block(120, radius: 14),
            block(96, radius: 14),
            block(64, radius: 14),
          ],
        ),
      ),
    );
  }
}
