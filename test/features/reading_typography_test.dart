import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moodiary/features/block/block_renderer.dart';
import 'package:moodiary/features/smart_canvas/widgets/reading_typography.dart';
import 'package:moodiary/features/smart_canvas/widgets/relative_time.dart';

void main() {
  group('relativeTimeLabel（卡片头 / 详情页元信息共用）', () {
    final now = DateTime(2026, 9, 16, 12, 0);

    test('刚刚 / 分钟 / 小时 / 天', () {
      expect(relativeTimeLabel(now, now: now), '刚刚');
      expect(
        relativeTimeLabel(now.subtract(const Duration(seconds: 30)), now: now),
        '刚刚',
      );
      expect(
        relativeTimeLabel(now.subtract(const Duration(minutes: 5)), now: now),
        '5 分钟前',
      );
      expect(
        relativeTimeLabel(now.subtract(const Duration(hours: 3)), now: now),
        '3 小时前',
      );
      expect(
        relativeTimeLabel(now.subtract(const Duration(days: 2)), now: now),
        '2 天前',
      );
    });

    test('超过 30 天回落绝对时间；未来时间按刚刚处理', () {
      expect(
        relativeTimeLabel(DateTime(2026, 7, 1, 9, 5), now: now),
        '7月1日 09:05',
      );
      expect(
        relativeTimeLabel(now.add(const Duration(minutes: 5)), now: now),
        '刚刚',
      );
    });
  });

  group('ReadingTypography（详情页卡片标题层级）', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    test('标题整体收敛：H1 明显小于默认 32，层级递增', () {
      final configs = ReadingTypography.configs(scheme);
      expect(configs, hasLength(6));
      final sizes = [
        for (final config in configs)
          if (config is HeadingConfig) config.style.fontSize!,
      ];
      expect(sizes.first, lessThan(24));
      expect(sizes.first, greaterThan(sizes[1]));
      expect(sizes[1], greaterThan(sizes[2]));
      expect(sizes[2], greaterThan(sizes[3]));
    });

    test('卡片口径与默认口径可区分（默认不改其它页面）', () {
      expect(MarkdownHeadingScale.standard, isNot(MarkdownHeadingScale.card));
    });
  });
}
