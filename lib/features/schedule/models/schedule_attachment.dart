/// 事件附件元信息（iOS 18 风「事件加附件」）。
///
/// 本阶段只记录**元信息**（本地路径可选），真正的上传/下载走 Hermes
/// `/api/calendar/events/{id}/attachments`（见 docs/日历-iOS18改造方案.md §4）。
class ScheduleAttachment {
  /// 远端附件 id（本地新建时为空，上传后回填）
  String id;

  /// 文件名（展示用，含扩展名）
  String name;

  /// 字节大小（展示为 320 KB / 2.4 MB）
  int size;

  /// 本地文件路径（可为空：仅记录元信息的场景）
  String? path;

  /// MIME（如 application/pdf），用于选图标
  String? mime;

  ScheduleAttachment({
    this.id = '',
    required this.name,
    this.size = 0,
    this.path,
    this.mime,
  });

  factory ScheduleAttachment.fromJson(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return ScheduleAttachment(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      path: map['path']?.toString(),
      mime: map['mime']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    if (path != null) 'path': path,
    if (mime != null) 'mime': mime,
  };

  ScheduleAttachment clone() => ScheduleAttachment(
    id: id,
    name: name,
    size: size,
    path: path,
    mime: mime,
  );

  /// 人类可读大小：1.1 MB / 320 KB / 812 B。
  String get sizeLabel {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) return '${(size / 1024).round()} KB';
    return '$size B';
  }
}
