import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/widgets/ai_model_field.dart';

void main() {
  group('ModelDropdownModel 纯函数', () {
    test('官方模型去空白/去重/保序', () {
      expect(ModelDropdownModel.options([' b', 'a', 'a ', '', 'b']), [
        'b',
        'a',
      ]);
      expect(ModelDropdownModel.options(const []), isEmpty);
    });

    test('哨兵值不参与官方列表', () {
      expect(
        ModelDropdownModel.options([
          ModelDropdownModel.customValue,
          'whisper-1',
        ]),
        ['whisper-1'],
      );
    });

    test('可选项 = 官方模型 + 当前值（不在列表时补） + 自定义哨兵', () {
      expect(
        ModelDropdownModel.values(
          models: const ['a', 'b'],
          current: 'qwen3-asr-flash',
        ),
        ['a', 'b', 'qwen3-asr-flash', ModelDropdownModel.customValue],
      );
      // 当前值已在官方列表里 → 不重复补
      expect(
        ModelDropdownModel.values(models: const ['a', 'b'], current: 'a'),
        ['a', 'b', ModelDropdownModel.customValue],
      );
      // 空当前值 → 不补
      expect(ModelDropdownModel.values(models: const ['a'], current: ''), [
        'a',
        ModelDropdownModel.customValue,
      ]);
    });

    test('safeValue：空值/不在可选项 → null（避免 DropdownButton 断言）', () {
      const items = ['a', 'b', ModelDropdownModel.customValue];
      expect(ModelDropdownModel.safeValue(current: 'a', items: items), 'a');
      expect(ModelDropdownModel.safeValue(current: '', items: items), isNull);
      expect(ModelDropdownModel.safeValue(current: '  ', items: items), isNull);
      expect(ModelDropdownModel.safeValue(current: 'x', items: items), isNull);
    });

    test('isCustom 判定', () {
      expect(
        ModelDropdownModel.isCustom(current: 'x', models: const ['a']),
        isTrue,
      );
      expect(
        ModelDropdownModel.isCustom(current: 'a', models: const ['a']),
        isFalse,
      );
      expect(
        ModelDropdownModel.isCustom(current: '', models: const ['a']),
        isFalse,
      );
    });
  });

  group('AiModelField 组件（真机红屏回归）', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('有官方模型但模型名为空 → 不再断言崩溃（真机截图场景）', (tester) async {
      await pump(
        tester,
        AiModelField(
          models: const ['whisper-1', 'qwen3-asr-flash'],
          modelName: '',
          onChanged: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('选择模型…'), findsOneWidget);
    });

    testWidgets('官方模型列表带重复项 → 不崩（同值多项也会触发断言）', (tester) async {
      await pump(
        tester,
        AiModelField(
          models: const ['whisper-1', 'whisper-1', 'whisper-1'],
          modelName: 'whisper-1',
          onChanged: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('whisper-1'), findsOneWidget);
    });

    testWidgets('模型名不在官方列表 → 补一条「（自定义）」并正常显示', (tester) async {
      await pump(
        tester,
        AiModelField(
          models: const ['whisper-1'],
          modelName: 'qwen3-asr-flash',
          onChanged: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('qwen3-asr-flash（自定义）'), findsOneWidget);
    });

    testWidgets('无官方模型且未设置 → 回退手输框', (tester) async {
      await pump(
        tester,
        AiModelField(models: const [], modelName: '', onChanged: (_) {}),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('选择官方模型会回调新值', (tester) async {
      String picked = '';
      await pump(
        tester,
        AiModelField(
          models: const ['whisper-1', 'qwen3-asr-flash'],
          modelName: '',
          onChanged: (v) => picked = v,
        ),
      );
      await tester.tap(find.text('选择模型…'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // 展开后才会渲染候选项（关着的时候只有选中项/hint 在树上）
      expect(find.text('自定义…'), findsOneWidget);
      await tester.tap(find.text('qwen3-asr-flash').last);
      await tester.pumpAndSettle();
      expect(picked, 'qwen3-asr-flash');
    });
  });
}
