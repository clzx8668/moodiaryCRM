import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/model_name_fix.dart';

void main() {
  // 真机（荣耀 Magic3 Pro）实测文案
  const realMessage =
      'The supported API model names are deepseek-flash, deepseek-v4-pro, '
      'but you passed DeepSeek-V4-Flash.';

  group('解析服务端可选模型', () {
    test('从真实报错文案里解析出列表', () {
      expect(ModelNameFix.parseSupported(realMessage), [
        'deepseek-flash',
        'deepseek-v4-pro',
      ]);
    });

    test('无标志短语 / 空文案返回空列表', () {
      expect(ModelNameFix.parseSupported('something else'), isEmpty);
      expect(ModelNameFix.parseSupported(''), isEmpty);
      expect(ModelNameFix.parseSupported(null), isEmpty);
    });
  });

  group('模型名匹配', () {
    const supported = [
      'deepseek-flash',
      'deepseek-v4-pro',
      'deepseek-v4-flash',
    ];

    test('忽略大小写与连字符/下划线差异', () {
      expect(
        ModelNameFix.match(
          requested: 'DeepSeek-V4-Flash',
          supported: supported,
        ),
        'deepseek-v4-flash',
      );
      expect(
        ModelNameFix.match(
          requested: 'deepseek_v4_flash',
          supported: supported,
        ),
        'deepseek-v4-flash',
      );
    });

    test('允许展示名带前缀（QW- 等）', () {
      expect(
        ModelNameFix.match(
          requested: 'QW-DeepSeek-V4-Flash',
          supported: supported,
        ),
        'deepseek-v4-flash',
      );
    });

    test('匹配不到时返回 null（不瞎改配置）', () {
      expect(
        ModelNameFix.match(requested: 'gpt-4o', supported: supported),
        isNull,
      );
      expect(ModelNameFix.match(requested: '', supported: supported), isNull);
      expect(ModelNameFix.match(requested: 'x', supported: const []), isNull);
    });
  });

  group('fromError 一步到位', () {
    test('大小写不符 → 给出规范名', () {
      expect(
        ModelNameFix.fromError(
          requested: 'DeepSeek-V4-Pro',
          message: realMessage,
        ),
        'deepseek-v4-pro',
      );
    });

    test('服务端不支持该型号（列表里没有等价名）→ 不瞎猜', () {
      // 真机现场就是这种情况：配置 DeepSeek-V4-Flash，但账号只支持
      // deepseek-flash / deepseek-v4-pro —— 必须用户去设置里改，不能自动降级
      expect(
        ModelNameFix.fromError(
          requested: 'DeepSeek-V4-Flash',
          message: realMessage,
        ),
        isNull,
      );
      expect(
        ModelNameFix.fromError(
          requested: 'DeepSeek-V4-Flash',
          message:
              'The supported API model names are deepseek-flash, '
              'deepseek-v4-pro, deepseek-v4-flash, but you passed '
              'DeepSeek-V4-Flash.',
        ),
        'deepseek-v4-flash',
      );
    });

    test('已经是规范名 → 不重试（返回 null）', () {
      expect(
        ModelNameFix.fromError(
          requested: 'deepseek-v4-pro',
          message: realMessage,
        ),
        isNull,
      );
      expect(
        ModelNameFix.fromError(
          requested: 'deepseek-flash',
          message: realMessage,
        ),
        isNull,
      );
    });

    test('文案里没有可选列表 → 不干预', () {
      expect(
        ModelNameFix.fromError(
          requested: 'DeepSeek-V4-Flash',
          message: 'Internal server error',
        ),
        isNull,
      );
    });
  });
}
