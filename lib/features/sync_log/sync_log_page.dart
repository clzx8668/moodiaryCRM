import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/utils/notice_util.dart';

/// 同步日志查看页（架构文档 4.8：最近 500 条、级别/时间筛选、一键清空）
class SyncLogPage extends StatefulWidget {
  const SyncLogPage({super.key});

  @override
  State<SyncLogPage> createState() => _SyncLogPageState();
}

class _SyncLogPageState extends State<SyncLogPage> {
  final log = SyncLogService.instance;
  final _levels = <SyncLogLevel>{
    SyncLogLevel.info,
    SyncLogLevel.warn,
    SyncLogLevel.error,
  };

  @override
  Widget build(BuildContext context) {
    final entries = log.query(levels: _levels).reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('同步日志'),
        actions: [
          IconButton(
            tooltip: '清空日志',
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () async {
              await log.clear();
              toast.success(message: '日志已清空');
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final level in SyncLogLevel.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(level.label),
                      selected: _levels.contains(level),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _levels.add(level);
                          } else {
                            _levels.remove(level);
                          }
                        });
                      },
                    ),
                  ),
                const Spacer(),
                Text('${entries.length} 条', style: context.textTheme.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('暂无日志'))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          entry.level == SyncLogLevel.error
                              ? Icons.error_outline
                              : entry.level == SyncLogLevel.warn
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline,
                          color: entry.level == SyncLogLevel.error
                              ? Colors.red
                              : entry.level == SyncLogLevel.warn
                              ? Colors.orange
                              : null,
                        ),
                        title: Text(
                          '[${entry.operation}] ${entry.target}',
                          style: context.textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          '${entry.detail}'
                          '${entry.error == null ? "" : "\n错误：${entry.error}"}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          entry.timestamp.toLocal().toString(),
                          style: context.textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
