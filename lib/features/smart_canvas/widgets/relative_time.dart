import 'package:intl/intl.dart';

/// 相对时间文案（纯函数，卡片头与详情页元信息共用）。
///
/// 规则：刚刚 / N 分钟前 / N 小时前 / N 天前；超过 30 天回落为「M月d日 HH:mm」。
String relativeTimeLabel(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.isNegative) return '刚刚';
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  return DateFormat('M月d日 HH:mm').format(time);
}
