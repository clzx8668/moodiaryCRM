import 'dart:convert';
import 'dart:io';

/// Twenty CRM 连接配置
class TwentyConfig {
  final String baseUrl;
  final String apiToken;
  final String? workspaceId;
  final int timeoutSeconds;

  const TwentyConfig({
    required this.baseUrl,
    required this.apiToken,
    this.workspaceId,
    this.timeoutSeconds = 15,
  });

  factory TwentyConfig.fromJson(Map<String, dynamic> json) {
    return TwentyConfig(
      baseUrl: (json['baseUrl'] as String?)?.replaceAll(RegExp(r'/+$'), '') ??
          'http://localhost:3000',
      apiToken: json['apiToken'] as String? ?? '',
      workspaceId: json['workspaceId'] as String?,
      timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt() ?? 15,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'apiToken': apiToken,
      'workspaceId': workspaceId,
      'timeoutSeconds': timeoutSeconds,
    };
  }

  bool get isConfigured => baseUrl.isNotEmpty && apiToken.isNotEmpty;

  /// 加载本地配置（不入 git）。
  /// 查找顺序：
  /// 1. 环境变量 TWENTY_CONFIG 指定的路径；
  /// 2. 当前工作目录 config/twenty.local.json（开发/脚本）；
  /// 3. 应用支持目录 config/twenty.local.json（运行期）。
  static Future<TwentyConfig> loadLocal() async {
    final envPath = Platform.environment['TWENTY_CONFIG'];
    if (envPath != null && File(envPath).existsSync()) {
      return _fromFile(File(envPath));
    }

    final candidates = <String>[
      'config/twenty.local.json',
    ];
    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) {
        return _fromFile(file);
      }
    }

    throw const FileSystemException('未找到 Twenty 配置：config/twenty.local.json');
  }

  static TwentyConfig _fromFile(File file) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return TwentyConfig.fromJson(json);
  }
}
