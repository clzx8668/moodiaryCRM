import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/voice/voice_capture_controller.dart';
import 'package:moodiary/features/voice/widgets/voice_capture_panel.dart';

/// 假录音器：面板测试只验证 UI，不触发任何真实异步（fake async 下会挂）
class _FakeRecorder implements VoiceCaptureRecorder {
  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start(String path, {required bool wav}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<double> amplitudeDb() => const Stream<double>.empty();

  @override
  Future<Stream<Uint8List>> startPcmStream({int sampleRate = 16000}) async =>
      const Stream<Uint8List>.empty();

  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory tempDir;
  late _FakeRecorder recorder;
  late VoiceCaptureController controller;
  final calls = <String>[];

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('voice_panel_test');
    recorder = _FakeRecorder();
    controller = VoiceCaptureController(
      recorder: recorder,
      isDesktop: false,
      idGenerator: () => 'panel-id',
      audioPathResolver: (name) => '${tempDir.path}/$name',
    );
    calls.clear();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// 直接构造目标状态：录音流程本身由 voice_capture_controller_test 覆盖，
  /// 这里只关心各阶段该出现哪些按钮（也避免 widget test 的 fake async 卡住 await）
  void givenRecording({Duration elapsed = const Duration(seconds: 12)}) {
    controller.phase.value = VoiceCapturePhase.recording;
    controller.elapsed.value = elapsed;
  }

  void givenPaused({Duration elapsed = const Duration(seconds: 7)}) {
    controller.phase.value = VoiceCapturePhase.paused;
    controller.elapsed.value = elapsed;
  }

  void givenStopped({Duration elapsed = const Duration(seconds: 9)}) {
    controller.audioFileName = 'voice-test.m4a';
    controller.phase.value = VoiceCapturePhase.stopped;
    controller.elapsed.value = elapsed;
  }

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: VoiceCapturePanel(
              controller: controller,
              onExitKeyboard: () => calls.add('keyboard'),
              onCancel: () => calls.add('cancel'),
              onRetake: () => calls.add('retake'),
              onSave: () => calls.add('save'),
              previewBuilder: (_) => const SizedBox(height: 24),
            ),
          ),
        ),
      ),
    );
    // 注意：录音中控制器每 200ms 刷新时长 → 用 pump 而不是 pumpAndSettle
    await tester.pump();
  }

  testWidgets('录音中：显示暂停 / 停止，时长可见', (tester) async {
    givenRecording();
    await pumpPanel(tester);

    expect(find.text('正在录音'), findsOneWidget);
    expect(find.text('00:12'), findsOneWidget);
    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('停止'), findsOneWidget);
    expect(find.text('保存并转写'), findsNothing);
  });

  testWidgets('已暂停：显示继续 / 停止', (tester) async {
    givenPaused();
    await pumpPanel(tester);

    expect(find.text('已暂停'), findsOneWidget);
    expect(find.text('00:07'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);
    expect(find.text('停止'), findsOneWidget);
  });

  testWidgets('停止后：试听 + 取消 / 重录 / 保存并转写', (tester) async {
    givenStopped();
    await pumpPanel(tester);

    expect(find.text('录音完成'), findsOneWidget);
    expect(find.text('00:09'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('重录'), findsOneWidget);
    expect(find.text('保存并转写'), findsOneWidget);
    expect(find.text('试听这段录音'), findsNothing); // 测试里用占位组件替换播放器
  });

  testWidgets('停止后三个动作各自回调（保存/取消/重录）', (tester) async {
    givenStopped();
    await pumpPanel(tester);

    await tester.tap(find.text('保存并转写'));
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.tap(find.text('重录'));
    await tester.pump();

    expect(calls, ['save', 'cancel', 'retake']);
  });

  testWidgets('录音中可切回键盘输入', (tester) async {
    givenRecording();
    await pumpPanel(tester);
    await tester.tap(find.byTooltip('切回键盘输入'));
    await tester.pump();
    expect(calls, ['keyboard']);
  });
}
