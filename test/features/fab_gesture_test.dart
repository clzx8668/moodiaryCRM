import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/quick_capture/fab_gesture.dart';

void main() {
  group('FAB 手势判定', () {
    test('上滑展开菜单（速度超过阈值）', () {
      expect(FabGesturePolicy.swipe(-600), FabSwipeAction.openMenu);
      expect(
        FabGesturePolicy.swipe(-FabGesturePolicy.swipeVelocityThreshold),
        FabSwipeAction.openMenu,
      );
    });

    test('下滑收起菜单', () {
      expect(FabGesturePolicy.swipe(600), FabSwipeAction.closeMenu);
      expect(
        FabGesturePolicy.swipe(FabGesturePolicy.swipeVelocityThreshold),
        FabSwipeAction.closeMenu,
      );
    });

    test('速度不足或未知视为误触', () {
      expect(FabGesturePolicy.swipe(null), FabSwipeAction.none);
      expect(FabGesturePolicy.swipe(0), FabSwipeAction.none);
      expect(
        FabGesturePolicy.swipe(FabGesturePolicy.swipeVelocityThreshold - 1),
        FabSwipeAction.none,
      );
      expect(
        FabGesturePolicy.swipe(-FabGesturePolicy.swipeVelocityThreshold + 1),
        FabSwipeAction.none,
      );
    });
  });

  group('一次性手势提示', () {
    test('未提示过 → 展示；已提示 → 不再展示', () {
      expect(FabGesturePolicy.shouldShowHint(null), isTrue);
      expect(FabGesturePolicy.shouldShowHint(false), isTrue);
      expect(FabGesturePolicy.shouldShowHint(true), isFalse);
    });
  });
}
