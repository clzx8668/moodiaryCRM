import 'dart:convert';
import 'dart:io';

/// 同步日志级别
enum SyncLogLevel {
  info('INFO'),
  warn('WARN'),
  error('ERROR');

  final String label;
  const SyncLogLevel(this.label);

  static SyncLogLevel fromLabel(String label) {
    return SyncLogLevel.values.firstWhere(
      (e) => e.label == label,
      orElse: () => SyncLogLevel.info,
    );
  }
}

/// 同步日志条目（对齐架构文档 4.8 结构化 JSON 日志）
class SyncLogEntry {
  final DateTime timestamp;
  final SyncLogLevel level;
  final String operation; // pull/push/upload/download/test/connect
  final String target; // diary/block/file/crm/company/person/opportunity/task
  final String detail;
  final String? error;

  const SyncLogEntry({
    required this.timestamp,
    required this.level,
    required this.operation,
    required this.target,
    required this.detail,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.label,
      'operation': operation,
      'target': target,
      'detail': detail,
      if (error != null) 'error': error,
    };
  }

  factory SyncLogEntry.fromJson(Map<String, dynamic> json) {
    return SyncLogEntry(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      level: SyncLogLevel.fromLabel(json['level'] as String? ?? 'INFO'),
      operation: json['operation'] as String? ?? '',
      target: json['target'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      error: json['error'] as String?,
    );
  }
}

/// 同步日志服务：内存环形缓冲（最近 500 条）+ JSONL 落盘
class SyncLogService {
  SyncLogService._();

  static final SyncLogService instance = SyncLogService._();

  static const int maxEntries = 500;

  final List<SyncLogEntry> _entries = [];
  File? _logFile;

  List<SyncLogEntry> get entries => List.unmodifiable(_entries);

  /// 设置日志文件（默认 logs/sync.log）
  void attachLogFile(File file) {
    _logFile = file;
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
  }

  Future<void> write({
    required SyncLogLevel level,
    required String operation,
    required String target,
    required String detail,
    String? error,
  }) async {
    final entry = SyncLogEntry(
      timestamp: DateTime.now(),
      level: level,
      operation: operation,
      target: target,
      detail: detail,
      error: error,
    );
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    await _appendToFile(entry);
  }

  Future<void> _appendToFile(SyncLogEntry entry) async {
    final file = _logFile;
    if (file == null) return;
    try {
      final sink = file.openSync(mode: FileMode.append);
      try {
        sink.writeStringSync('${jsonEncode(entry.toJson())}\n');
      } finally {
        sink.closeSync();
      }
    } catch (_) {
      // 日志失败不影响业务
    }
  }

  /// 读取指定级别与时间范围（时间范围传 null 表示不限）
  List<SyncLogEntry> query({
    Set<SyncLogLevel>? levels,
    DateTime? from,
    DateTime? to,
  }) {
    return _entries.where((e) {
      if (levels != null && !levels.contains(e.level)) return false;
      if (from != null && e.timestamp.isBefore(from)) return false;
      if (to != null && e.timestamp.isAfter(to)) return false;
      return true;
    }).toList();
  }

  Future<void> clear() async {
    _entries.clear();
    final file = _logFile;
    if (file != null && file.existsSync()) {
      await file.writeAsString('');
    }
  }

  /// 从既有日志文件恢复最近条目（应用启动时调用）
  Future<void> loadFromFile(File file) async {
    attachLogFile(file);
    if (!file.existsSync()) return;
    final lines = await file.readAsLines();
    final restored = lines.reversed
        .take(maxEntries)
        .map((line) {
          try {
            return SyncLogEntry.fromJson(
              jsonDecode(line) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<SyncLogEntry>()
        .toList()
        .reversed
        .toList();
    _entries
      ..clear()
      ..addAll(restored);
  }
}
