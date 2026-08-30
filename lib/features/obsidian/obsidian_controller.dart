import 'package:get/get.dart';
import 'package:moodiary/features/obsidian/obsidian_service.dart';

/// Obsidian 选中态共享控制器：左侧二级导航抽屉选中文件后，
/// Obsidian 页通过 Obx 自动渲染对应笔记。
class ObsidianController extends GetxController {
  ObsidianController._();

  static final ObsidianController instance = ObsidianController._();

  final Rx<ObsidianFile?> selectedFile = Rx<ObsidianFile?>(null);

  void select(ObsidianFile file) => selectedFile.value = file;
}
