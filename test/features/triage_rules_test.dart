import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/triage/triage_rules.dart';

void main() {
  group('TriageRules｜第一级规则引擎（敏感信息）', () {
    test('手机号 / 身份证 / 银行卡 / 邮箱 / 密钥都能识别', () {
      expect(TriageRules.detectSensitive('联系我 13812345678'), contains('手机号'));
      expect(
        TriageRules.detectSensitive('身份证 11010119900307617X'),
        contains('身份证号'),
      );
      expect(
        TriageRules.detectSensitive('卡号 6222 0212 3456 7890'),
        contains('银行卡号'),
      );
      expect(
        TriageRules.detectSensitive('邮箱 a.b@example.com'),
        contains('邮箱'),
      );
      expect(
        TriageRules.detectSensitive('api_key: sk-abcdefghijklmnopqrstuvwxyz'),
        contains('密钥/Token'),
      );
    });

    test('普通文本不会误报', () {
      expect(TriageRules.detectSensitive('明天上午十点开会讨论方案'), isEmpty);
      expect(TriageRules.detectSensitive('今天写了三页笔记'), isEmpty);
      // 短数字不该被当成身份证/银行卡
      expect(TriageRules.detectSensitive('买了 3 个苹果共 25 元'), isEmpty);
    });

    test('密码类要求同时出现长数字，避免误判', () {
      expect(TriageRules.detectSensitive('我忘了密码'), isEmpty);
      expect(TriageRules.detectSensitive('密码是 8823'), isEmpty);
      expect(TriageRules.detectSensitive('密码 88234567'), contains('密码'));
    });
  });

  group('TriageRules｜抽取信号', () {
    test('待办/时间线索能命中', () {
      expect(TriageRules.hasTodoSignal('明天记得交报告'), isTrue);
      expect(TriageRules.hasTodoSignal('会议定在 15:30'), isTrue);
      expect(TriageRules.hasTodoSignal('下午6点前发出去'), isTrue);
      expect(TriageRules.hasTodoSignal('楼下那只猫又来了'), isFalse);
      // "今天"属于低特异性时间词：算时间线索，但打分权重低（见 signal_scorer_test）
      expect(TriageRules.hasTodoSignal('今天天气不错'), isTrue);
    });

    test('CRM 信号能命中', () {
      expect(TriageRules.hasCrmSignal('客户对报价有异议'), isTrue);
      expect(TriageRules.hasCrmSignal('合同下周签'), isTrue);
      expect(TriageRules.hasCrmSignal('买了点水果'), isFalse);
    });

    test('URL 视为可抽取内容', () {
      expect(TriageRules.hasExtractableSignal('看这个 https://a.com/x'), isTrue);
      expect(TriageRules.hasExtractableSignal('记录一下今天'), isFalse);
    });
  });

  group('TriageRules｜无用内容识别', () {
    test('过短 / 纯符号 / 纯数字 视为 trivial', () {
      expect(TriageRules.isTrivial(''), isTrue);
      expect(TriageRules.isTrivial('。。。'), isTrue);
      expect(TriageRules.isTrivial('123'), isTrue);
      expect(TriageRules.isTrivial('嗯'), isTrue);
      expect(TriageRules.isTrivial('今天开会'), isFalse);
    });

    test('测试占位内容被识别（短且含占位词）', () {
      expect(TriageRules.looksPlaceholder('test'), isTrue);
      expect(TriageRules.looksPlaceholder('测试一下'), isTrue);
      expect(TriageRules.looksPlaceholder('aaaa'), isTrue);
      // 长内容即使含"测试"也当正常内容
      expect(
        TriageRules.looksPlaceholder('今天测试了新的报价流程，发现三个问题需要修'),
        isFalse,
      );
    });

    test('结构度：成篇内容命中', () {
      expect(TriageRules.looksStructured('第一点。第二点。第三点。第四点。'), isTrue);
      expect(TriageRules.looksStructured('- 甲\n- 乙'), isTrue);
      expect(TriageRules.looksStructured('随便写写'), isFalse);
    });

    test('私人情绪记录能识别', () {
      expect(TriageRules.looksPrivateJournal('今天心情有点低落'), isTrue);
      expect(TriageRules.looksPrivateJournal('这个方案需要改'), isFalse);
    });
  });
}
