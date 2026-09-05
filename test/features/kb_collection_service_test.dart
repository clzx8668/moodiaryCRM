import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/collection/kb_collection_service.dart';

void main() {
  group('KbCollectionService', () {
    test('parse/encode 去重保序', () {
      expect(KbCollectionService.parse(' a, b ,a '), ['a', 'b']);
      expect(KbCollectionService.encode(['a', 'b', 'a']), 'a,b');
    });
    test('add/remove 幂等', () {
      var raw = '';
      raw = KbCollectionService.add(raw, 'kb1');
      raw = KbCollectionService.add(raw, 'kb2');
      raw = KbCollectionService.add(raw, 'kb1'); // 重复
      expect(KbCollectionService.contains(raw, 'kb1'), isTrue);
      expect(raw, 'kb1,kb2');
      raw = KbCollectionService.remove(raw, 'kb1');
      expect(KbCollectionService.contains(raw, 'kb1'), isFalse);
    });
  });
}
