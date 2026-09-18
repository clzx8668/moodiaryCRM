/// 首页 FAB 的手势语义（批次 89）。
///
/// 背景：用户要求「长按 FAB 直接开始录音」（对标 Get 笔记的按住说话），
/// 而原长按是「展开菜单（新建日记 / 回到顶部）」。为避免菜单无处可达，
/// 手势重新分配为：
/// - 轻点 → 快速收集面板（不变）
/// - 长按 → 直达语音记录页并自动开始录音（新增）
/// - 上滑 → 展开菜单；下滑 → 收起菜单（原长按行为迁移）
enum FabSwipeAction {
  /// 上滑：展开菜单
  openMenu,

  /// 下滑：收起菜单
  closeMenu,

  /// 位移过小：不处理
  none,
}

/// 纯函数手势判定，便于单测（widget 层只做转发）。
class FabGesturePolicy {
  FabGesturePolicy._();

  /// 判定阈值（px/s）：低于该速度视为误触。
  static const double swipeVelocityThreshold = 180;

  /// 一次性手势提示的 Pref 键。
  static const String hintPrefKey = 'fabGestureHintShown';

  /// 一次性提示文案（长按录音首次生效时展示）。
  static const String hintMessage = '长按录音已就绪 · 上滑 FAB 打开菜单';

  /// 上滑展开、下滑收起；速度不足不处理。
  static FabSwipeAction swipe(double? primaryVelocity) {
    if (primaryVelocity == null) return FabSwipeAction.none;
    if (primaryVelocity <= -swipeVelocityThreshold) {
      return FabSwipeAction.openMenu;
    }
    if (primaryVelocity >= swipeVelocityThreshold) {
      return FabSwipeAction.closeMenu;
    }
    return FabSwipeAction.none;
  }

  /// 是否还需要展示一次性提示。
  static bool shouldShowHint(bool? shown) => shown != true;
}
