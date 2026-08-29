import 'package:get/get.dart';
import 'package:moodiary/persistence/pref.dart';

/// Obsidian 对接配置（Rx 便于首页 tab 行响应式显隐）。
class ObsidianConfig {
  ObsidianConfig._();

  static final RxBool enabled =
      (PrefUtil.getValue<bool>('obsidianEnabled') ?? false).obs;

  static final RxString vaultPath =
      (PrefUtil.getValue<String>('obsidianVaultPath') ?? '').obs;

  static bool get isReady => enabled.value && vaultPath.value.trim().isNotEmpty;

  static Future<void> save({bool? enabled, String? vaultPath}) async {
    if (enabled != null) {
      ObsidianConfig.enabled.value = enabled;
      await PrefUtil.setValue<bool>('obsidianEnabled', enabled);
    }
    if (vaultPath != null) {
      ObsidianConfig.vaultPath.value = vaultPath.trim();
      await PrefUtil.setValue<String>('obsidianVaultPath', vaultPath.trim());
    }
  }
}
