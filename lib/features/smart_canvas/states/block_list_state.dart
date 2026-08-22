import 'package:get/get.dart';
import 'package:moodiary/features/block/models/block.dart';

/// BlockListState：卡片栈的原始数据（架构文档 6.2）。
///
/// 只管理"有哪些卡片"，不关心 AI 流式 / 编辑 / 搜索 / 同步。
class BlockListState {
  /// 未删除卡片，按 sortOrder 升序
  final RxList<Block> blocks = <Block>[].obs;

  /// 首次加载中
  final RxBool loading = false.obs;

  /// 是否已初始化（初始卡兜底已执行）
  final RxBool initialized = false.obs;

  /// 当前最大排序号（追加新卡时 +1）
  int get maxSortOrder {
    if (blocks.isEmpty) return -1;
    return blocks.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b);
  }

  /// 替换单个卡片（编辑返回 / AI 转正后局部刷新）
  void replace(Block block) {
    final index = blocks.indexWhere((b) => b.id == block.id);
    if (index >= 0) {
      blocks[index] = block;
    }
  }

  /// 按 id 查找
  Block? byId(String id) {
    for (final block in blocks) {
      if (block.id == id) return block;
    }
    return null;
  }

  /// 移除（软删后从列表摘除）
  void remove(String id) {
    blocks.removeWhere((b) => b.id == id);
  }
}
