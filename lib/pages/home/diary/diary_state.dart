import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/common/values/diary_sort.dart';
import 'package:moodiary/common/values/view_mode.dart';
import 'package:moodiary/components/scroll/fix_scroll.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';

class DiaryState {
  //自定义标题名称，如果为空则为默认值
  late RxString customTitleName;

  //分类列表，用于tab显示
  late List<Category> categoryList;

  //分类列表对应的key map，key是列表id
  late Map<String, GlobalKey<PrimaryScrollWrapperState>> keyMap;

  //主滚动列表key
  late GlobalKey<NestedScrollViewState> nestedScrollKey;

  ScrollController get innerController =>
      nestedScrollKey.currentState!.innerController;

  ScrollController get outerController =>
      nestedScrollKey.currentState!.outerController;

  //视图模式状态
  late Rx<ViewModeType> viewModeType = ViewModeType.getType(
    PrefUtil.getValue<int>('homeViewMode')!,
  ).obs;

  // 记录排序方式（影响列表/网格/块三视图）
  late Rx<DiarySort> sort = DiarySort.fromIndex(
    PrefUtil.getValue<int>('homeSortOrder') ?? 0,
  ).obs;

  // 标签筛选（为空=不筛选）
  final RxList<String> filterTags = <String>[].obs;

  // 是否有生效筛选
  final RxBool filterActive = false.obs;

  //当前tab bar位置
  late int currentTabBarIndex;

  /// 二级导航侧栏展开状态（PC 默认展开，移动端默认收起）。
  final RxBool navExpanded = RxBool(
    defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS,
  );

  /// 二级导航侧栏展开宽度（可拖动调整并持久化，默认 180）。
  final RxDouble sidebarWidth = RxDouble(
    PrefUtil.getValue<double>('navSidebarWidth') ?? 180.0,
  );

  // 一言
  RxString hitokoto = '...'.obs;

  DiaryState() {
    customTitleName = PrefUtil.getValue<String>('customTitleName')!.obs;

    nestedScrollKey = GlobalKey<NestedScrollViewState>();

    currentTabBarIndex = 0;

    //第一次获取分类，这里是同步方法，因为分类数量是可控的，所以应该不会有性能问题，但愿如此
    categoryList = IsarUtil.getAllCategory();

    //默认分类
    keyMap = {'default': GlobalKey<PrimaryScrollWrapperState>()};
    //其他分类
    for (final category in categoryList) {
      keyMap[category.id] = GlobalKey<PrimaryScrollWrapperState>();
    }
  }
}
