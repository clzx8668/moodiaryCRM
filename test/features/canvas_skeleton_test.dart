import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/smart_canvas/widgets/canvas_skeleton.dart';

void main() {
  testWidgets('详情页骨架屏可正常构建并渲染占位块', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CanvasSkeleton())),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CanvasSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 呼吸动画运行中不应抛异常
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
