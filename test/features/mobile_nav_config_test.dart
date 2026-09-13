import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/nav/mobile_nav_config.dart';

void main() {
  group('MobileNavConfig.sanitize', () {
    test('默认四项保持', () {
      expect(
        MobileNavConfig.sanitize([0, 1, 4, 5]),
        MobileNavConfig.defaultItems,
      );
    });

    test('去重并按全量顺序排序', () {
      expect(MobileNavConfig.sanitize([5, 0, 0, 1, 4]), [0, 1, 4, 5]);
    });

    test('非法项剔除，不足两项回退默认', () {
      expect(MobileNavConfig.sanitize([9, 0]), MobileNavConfig.defaultItems);
      expect(MobileNavConfig.sanitize(const []), MobileNavConfig.defaultItems);
    });

    test('超过上限截断为 5 项', () {
      expect(MobileNavConfig.sanitize([0, 1, 2, 3, 4, 5]), [0, 1, 2, 3, 4]);
    });

    test('按 pageIndex 查目的地', () {
      expect(MobileNavConfig.byIndex(4)?.label, 'AI');
      expect(MobileNavConfig.byIndex(5)?.label, '设置');
      expect(MobileNavConfig.byIndex(99), isNull);
    });
  });
}
