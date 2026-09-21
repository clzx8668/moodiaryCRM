import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/calendar/quick_parse.dart';

void main() {
  // 固定"现在"＝2026-09-22 周二 09:00，保证断言稳定
  final now = DateTime(2026, 9, 22, 9);

  QuickParseResult p(String s) => parseQuickAdd(s, now: now);

  group('日期', () {
    test('今天/明天/后天/大后天', () {
      expect(p('今天下午3点开会').start, DateTime(2026, 9, 22, 15));
      expect(p('明天上午10点开会').start, DateTime(2026, 9, 23, 10));
      expect(p('后天晚上8点聚餐').start, DateTime(2026, 9, 24, 20));
      expect(p('大后天早上9点体检').start, DateTime(2026, 9, 25, 9));
    });

    test('周X（已过的那天按下周算）', () {
      // 9/22 是周二：周一是已过 → 下周一 9/28
      expect(p('周一上午9点例会').start, DateTime(2026, 9, 28, 9));
      // 周五还没到 → 本周五 9/25
      expect(p('周五下午2点评审').start, DateTime(2026, 9, 25, 14));
      // 显式"下周五"
      expect(p('下周五下午2点评审').start, DateTime(2026, 10, 2, 14));
    });

    test('X月X日 / X号', () {
      expect(p('10月1日上午10点出发').start, DateTime(2026, 10, 1, 10));
      // 本月 5 号已过 → 顺延到下月
      expect(p('5号下午3点交材料').start, DateTime(2026, 10, 5, 15));
      // 本月 28 号未到 → 本月
      expect(p('28号下午3点交材料').start, DateTime(2026, 9, 28, 15));
    });
  });

  group('时刻与时长', () {
    test('HH:MM 与 N点半', () {
      expect(p('明天 14:30 面试').start, DateTime(2026, 9, 23, 14, 30));
      expect(p('明天下午3点半面试').start, DateTime(2026, 9, 23, 15, 30));
      expect(p('明天上午9点15分开会').start, DateTime(2026, 9, 23, 9, 15));
    });

    test('时段：到 X点 / N小时 / N分钟', () {
      final a = p('明天下午2点到4点评审');
      expect(a.start, DateTime(2026, 9, 23, 14));
      expect(a.end, DateTime(2026, 9, 23, 16));

      final b = p('明天上午9点开2小时的会');
      expect(b.start, DateTime(2026, 9, 23, 9));
      expect(b.end, DateTime(2026, 9, 23, 11));

      final c = p('明天上午9点开45分钟站会');
      expect(c.end, DateTime(2026, 9, 23, 9, 45));
    });

    test('没写时长默认 1 小时', () {
      final r = p('明天下午2点开会');
      expect(r.end!.difference(r.start!), const Duration(hours: 1));
    });

    test('只写时段不写日期 → 落在今天', () {
      expect(p('下午4点和客户对方案').start, DateTime(2026, 9, 22, 16));
    });
  });

  group('地点与标题', () {
    test('「在 XX」抽地点', () {
      final r = p('明天下午2点在会议室A评审方案');
      expect(r.location, '会议室A');
      expect(r.title, '评审方案');
      expect(r.start, DateTime(2026, 9, 23, 14));
    });

    test('场所后缀识别', () {
      final r = p('明天上午10点虹桥机场接李总');
      expect(r.location, '虹桥机场');
      expect(r.title, '接李总');
    });

    test('没有时间词也能只出标题', () {
      final r = p('整理客户报价资料');
      expect(r.title, '整理客户报价资料');
      expect(r.start, isNull);
      expect(r.confidence, 0);
    });

    test('置信度随时段/地点要素增加', () {
      expect(p('明天下午2点在会议室A开会').confidence, greaterThan(0.7));
      expect(p('开会').confidence, 0);
    });
  });
}
