import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/triage/ai_result_cache.dart';

void main() {
  setUp(AiResultCache.clear);

  group('AiResultCache（相同内容不重复调用）', () {
    test('键只跟"操作 + 内容"相关，内容相同即相同', () {
      final a = AiResultCache.keyFor('extract_plan', '明天开会');
      final b = AiResultCache.keyFor('extract_plan', '  明天开会  ');
      final c = AiResultCache.keyFor('auto_tag', '明天开会');
      expect(a, b, reason: '前后空白不影响');
      expect(a, isNot(c), reason: '不同操作要分开缓存');
    });

    test('存入后能命中，命中计数增加', () {
      final key = AiResultCache.keyFor('extract_plan', '明天开会');
      expect(AiResultCache.get(key), isNull, reason: '首次必然未命中');
      AiResultCache.put(key, '{"actions":[]}');
      expect(AiResultCache.get(key), '{"actions":[]}');
      expect(AiResultCache.hits, 1);
      expect(AiResultCache.misses, 1);
      expect(AiResultCache.hitRate, closeTo(0.5, 1e-9));
    });

    test('LRU：超过容量后淘汰最久未使用的', () {
      for (var i = 0; i < AiResultCache.maxEntries; i++) {
        AiResultCache.put('k$i', 'v$i');
      }
      expect(AiResultCache.size, AiResultCache.maxEntries);
      // 访问 k0 让它变成"最近使用"
      expect(AiResultCache.get('k0'), 'v0');
      // 再插入一条 → 应淘汰 k1（最久未使用）
      AiResultCache.put('new', 'v');
      expect(AiResultCache.get('k0'), isNotNull, reason: '刚访问过，应保留');
      expect(AiResultCache.get('k1'), isNull, reason: '最久未使用，应被淘汰');
    });

    test('重复 put 同一个键不会膨胀容量', () {
      for (var i = 0; i < 10; i++) {
        AiResultCache.put('same', 'v$i');
      }
      expect(AiResultCache.size, 1);
      expect(AiResultCache.get('same'), 'v9');
    });

    test('clear 重置内容与统计', () {
      AiResultCache.put('k', 'v');
      AiResultCache.get('k');
      AiResultCache.clear();
      expect(AiResultCache.size, 0);
      expect(AiResultCache.hits, 0);
      expect(AiResultCache.misses, 0);
      expect(AiResultCache.hitRate, 0);
    });
  });
}
