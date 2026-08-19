import 'dart:io';

import 'package:moodiary/features/crm/twenty_api.dart';
import 'package:moodiary/features/crm/twenty_config.dart';

/// Twenty 连接自检脚本：
///   dart run tool/twenty_sync_check.dart
///
/// 读取 config/twenty.local.json（勿提交），验证连接并列出公司样例。
Future<void> main() async {
  final config = await TwentyConfig.loadLocal();
  stdout.writeln('Twenty 配置：${config.baseUrl}');
  if (!config.isConfigured) {
    stderr.writeln('错误：缺少 apiToken，请检查 config/twenty.local.json');
    exitCode = 1;
    return;
  }

  final client = TwentyApiClient(config: config);
  try {
    final ok = await client.ping();
    stdout.writeln('健康检查：${ok ? "OK" : "FAIL"}');

    final companies = await client.listAll(object: 'company');
    stdout.writeln('公司数量：${companies.length}');
    for (final company in companies.take(10)) {
      stdout.writeln('  - ${company.data['name']} (${company.id})');
    }

    final people = await client.listAll(object: 'person');
    stdout.writeln('联系人数量：${people.length}');

    final opportunities = await client.listAll(object: 'opportunity');
    stdout.writeln('商机数量：${opportunities.length}');

    final tasks = await client.listAll(object: 'task');
    stdout.writeln('任务数量：${tasks.length}');
    stdout.writeln('✅ 连接验证完成');
  } on TwentyApiException catch (e) {
    stderr.writeln('❌ 连接失败：$e');
    exitCode = 1;
  }
}
