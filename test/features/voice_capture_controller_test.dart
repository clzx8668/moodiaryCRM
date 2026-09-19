import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/voice/voice_capture_controller.dart';

/// 假录音器：记录调用顺序，不碰平台通道
class _FakeRecorder implements VoiceCaptureRecorder {
  bool permission = true;
  bool started = false;
  bool? wavFlag;
  String? startedPath;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  bool throwOnStart = false;
  final StreamController<double> amp = StreamController<double>.broadcast();

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> start(String path, {required bool wav}) async {
    if (throwOnStart) throw StateError('设备忙');
    started = true;
    wavFlag = wav;
    startedPath = path;
    File(path).writeAsStringSync('fake-audio');
  }

  @override
  Future<void> pause() async => pauseCount++;

  @override
  Future<void> resume() async => resumeCount++;

  @override
  Future<void> stop() async {
    stopCount++;
    started = false;
  }

  @override
  Stream<double> amplitudeDb() => amp.stream;

  @override
  Future<void> dispose() async {
    disposeCount++;
    await amp.close();
  }
}

void main() {
  late Directory tempDir;
  late _FakeRecorder recorder;
  late VoiceCaptureController controller;
  var now = DateTime(2026, 9, 19, 8);

  String resolve(String name) => '${tempDir.path}/$name';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('voice_capture_test');
    recorder = _FakeRecorder();
    now = DateTime(2026, 9, 19, 8);
    controller = VoiceCaptureController(
      recorder: recorder,
      clock: () => now,
      isDesktop: false,
      idGenerator: () => 'test-id',
      audioPathResolver: resolve,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('纯函数', () {
    test('文件名按平台给扩展名', () {
      expect(
        VoiceCaptureController.fileNameFor('abc', desktop: true),
        'voice-abc.wav',
      );
      expect(
        VoiceCaptureController.fileNameFor('abc', desktop: false),
        'voice-abc.m4a',
      );
    });

    test('时长文案 mm:ss（负数与进位）', () {
      expect(VoiceCaptureController.formatDuration(Duration.zero), '00:00');
      expect(
        VoiceCaptureController.formatDuration(const Duration(seconds: 9)),
        '00:09',
      );
      expect(
        VoiceCaptureController.formatDuration(
          const Duration(minutes: 2, seconds: 5),
        ),
        '02:05',
      );
      expect(
        VoiceCaptureController.formatDuration(const Duration(seconds: -3)),
        '00:00',
      );
      expect(
        VoiceCaptureController.formatDuration(const Duration(seconds: 3599)),
        '59:59',
      );
    });

    test('dB → 0…1 电平', () {
      expect(VoiceCaptureController.normalizeDb(-60), 0);
      expect(VoiceCaptureController.normalizeDb(-30), closeTo(0.5, 0.001));
      expect(VoiceCaptureController.normalizeDb(0), 1);
      expect(VoiceCaptureController.normalizeDb(10), 1);
      expect(VoiceCaptureController.normalizeDb(double.negativeInfinity), 0);
      expect(VoiceCaptureController.normalizeDb(double.nan), 0);
    });
  });

  group('录音流程（先录音、后决定）', () {
    test('start → recording，文件已落盘', () async {
      expect(await controller.start(), isNull);
      expect(controller.phase.value, VoiceCapturePhase.recording);
      expect(controller.audioFileName, 'voice-test-id.m4a');
      expect(recorder.started, isTrue);
      expect(recorder.wavFlag, isFalse);
      expect(File(controller.audioPath!).existsSync(), isTrue);
    });

    test('暂停后时长冻结，继续后恢复增长', () async {
      await controller.start();
      now = now.add(const Duration(seconds: 5));
      controller.phase.value; // 触发一次取值
      await controller.pause();
      expect(controller.phase.value, VoiceCapturePhase.paused);
      expect(recorder.pauseCount, 1);
      expect(controller.elapsed.value.inSeconds, 5);

      // 暂停期间时间流逝不计入
      now = now.add(const Duration(seconds: 30));
      await controller.resume();
      expect(controller.phase.value, VoiceCapturePhase.recording);
      expect(recorder.resumeCount, 1);

      now = now.add(const Duration(seconds: 3));
      await controller.stop();
      expect(controller.elapsed.value.inSeconds, 8);
    });

    test('stop → stopped 且保留文件（等用户决定）', () async {
      await controller.start();
      now = now.add(const Duration(seconds: 12));
      await controller.stop();
      expect(controller.phase.value, VoiceCapturePhase.stopped);
      expect(recorder.stopCount, 1);
      expect(controller.audioFileName, 'voice-test-id.m4a');
      expect(File(controller.audioPath!).existsSync(), isTrue);
      expect(controller.elapsed.value.inSeconds, 12);
    });

    test('取消（discard）→ 删除文件并回到 idle，不留记录', () async {
      await controller.start();
      final path = controller.audioPath!;
      await controller.stop();
      await controller.discard();
      expect(controller.phase.value, VoiceCapturePhase.idle);
      expect(controller.audioFileName, isNull);
      expect(controller.elapsed.value, Duration.zero);
      expect(File(path).existsSync(), isFalse);
    });

    test('录音中取消 → 停止录音并删文件', () async {
      await controller.start();
      final path = controller.audioPath!;
      await controller.discard();
      expect(recorder.stopCount, 1);
      expect(File(path).existsSync(), isFalse);
      expect(controller.phase.value, VoiceCapturePhase.idle);
    });

    test('保存后 reset：只清状态，不删文件（音频归入笔记附件）', () async {
      await controller.start();
      await controller.stop();
      final path = controller.audioPath!;
      controller.reset();
      expect(controller.phase.value, VoiceCapturePhase.idle);
      expect(controller.audioFileName, isNull);
      expect(File(path).existsSync(), isTrue);
    });

    test('重录：discard 后重新 start，文件名重新生成且旧文件被清理', () async {
      var seq = 0;
      final ctl = VoiceCaptureController(
        recorder: recorder,
        clock: () => now,
        isDesktop: true,
        idGenerator: () => 'id-${seq++}',
        audioPathResolver: resolve,
      );
      await ctl.start();
      final first = ctl.audioPath!;
      await ctl.discard();
      await ctl.start();
      expect(ctl.audioFileName, 'voice-id-1.wav');
      expect(File(first).existsSync(), isFalse);
      expect(File(ctl.audioPath!).existsSync(), isTrue);
      await ctl.dispose();
    });

    test('无麦克风权限 → 返回可读错误且不进入录音态', () async {
      recorder.permission = false;
      final error = await controller.start();
      expect(error, contains('麦克风权限'));
      expect(controller.phase.value, VoiceCapturePhase.idle);
      expect(recorder.started, isFalse);
    });

    test('底层启动失败 → 返回错误且状态回 idle', () async {
      recorder.throwOnStart = true;
      final error = await controller.start();
      expect(error, contains('录音失败'));
      expect(controller.phase.value, VoiceCapturePhase.idle);
      expect(controller.audioFileName, isNull);
    });

    test('未在录音时 stop/pause/resume 都是安全的空操作', () async {
      await controller.stop();
      await controller.pause();
      await controller.resume();
      expect(controller.phase.value, VoiceCapturePhase.idle);
      expect(recorder.stopCount, 0);
      expect(recorder.pauseCount, 0);
      expect(recorder.resumeCount, 0);
    });

    test('电平：dB 流驱动 level（-60→0、0→1）', () async {
      await controller.start();
      recorder.amp.add(-60);
      await Future<void>.delayed(Duration.zero);
      expect(controller.level.value, 0);
      recorder.amp.add(0);
      await Future<void>.delayed(Duration.zero);
      expect(controller.level.value, 1);
      await controller.stop();
      expect(controller.level.value, 0);
    });

    test('discardAndDispose 释放底层资源', () async {
      await controller.start();
      await controller.discardAndDispose();
      expect(recorder.disposeCount, 1);
    });
  });
}
