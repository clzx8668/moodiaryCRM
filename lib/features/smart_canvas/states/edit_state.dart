import 'package:get/get.dart';

/// EditState：当前编辑态（架构文档 6.2）。
class EditState {
  /// 当前正在编辑的 Block id（空 = 无编辑）
  final RxString editingBlockId = ''.obs;

  /// 编辑模式：markdown / entity / none
  final RxString mode = 'none'.obs;

  bool get isEditing => editingBlockId.value.isNotEmpty;

  void begin(String blockId, String editMode) {
    editingBlockId.value = blockId;
    mode.value = editMode;
  }

  void clear() {
    editingBlockId.value = '';
    mode.value = 'none';
  }
}
