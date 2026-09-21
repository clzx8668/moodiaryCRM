import 'dart:convert';

import 'package:crypto/crypto.dart';

/// **本地 AI 结果缓存**：相同内容不重复调用大模型。
///
/// 收益（成本/体验双重）：
/// - 同一条内容被重复处理（重试、重开详情页触发、批量重跑）时直接命中缓存，
///   不再花钱、不再等；
/// - 离线时如果之前算过，依然能立刻拿到结果。
///
/// 只在内存里（进程级 LRU）。刻意**不落盘**：AI 结果里可能含敏感推论，
/// 落盘会增加暴露面；进程重启后重新算一次是可以接受的代价。
class AiResultCache {
  AiResultCache._();

  /// 最多缓存多少条（按最近使用淘汰）
  static const int maxEntries = 120;

  /// 进程内缓存：key = 操作 + 内容指纹，value = 结果 JSON 文本
  static final Map<String, String> _store = <String, String>{};

  /// 统计：命中/未命中（供设置页展示"省了多少次调用"）
  static int hits = 0;
  static int misses = 0;

  /// 生成缓存键：`<operation>:<sha1(内容)>`
  ///
  /// 用内容指纹而不是日记 id：同一条内容被重新保存/移动位置也能命中。
  static String keyFor(String operation, String content) {
    final digest = sha1.convert(utf8.encode(content.trim())).toString();
    return '$operation:$digest';
  }

  /// 取缓存（命中会把该条移到末尾，实现 LRU）
  static String? get(String key) {
    final hit = _store.remove(key);
    if (hit == null) {
      misses++;
      return null;
    }
    _store[key] = hit;
    hits++;
    return hit;
  }

  /// 存缓存（超出容量淘汰最久未使用的）
  static void put(String key, String json) {
    _store.remove(key);
    _store[key] = json;
    while (_store.length > maxEntries) {
      _store.remove(_store.keys.first);
    }
  }

  /// 命中率（0..1；没访问过返回 0）
  static double get hitRate {
    final total = hits + misses;
    return total == 0 ? 0 : hits / total;
  }

  static int get size => _store.length;

  /// 仅供测试
  static void clear() {
    _store.clear();
    hits = 0;
    misses = 0;
  }
}
