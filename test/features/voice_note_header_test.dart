import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/voice/voice_note_info.dart';
import 'package:moodiary/features/voice/widgets/voice_note_header.dart';

void main() {
  final tabs = <VoiceNoteTab>[];
  var retries = 0;

  setUp(() {
    tabs.clear();
    retries = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    VoiceNoteInfo info, {
    VoiceNoteTab tab = VoiceNoteTab.note,
    VoidCallback? onRefine,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: VoiceNoteHeader(
              info: info,
              audioPath: '/tmp/voice-a.m4a',
              tab: tab,
              onTabChanged: tabs.add,
              onRetry: () => retries++,
              onRefine: onRefine,
              // 播放器换成占位：widget test 里不碰音频插件
              playerBuilder: (_) => const SizedBox(height: 56),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('转写中：显示进度与提示，不出现 Tab', (tester) async {
    await pump(
      tester,
      const VoiceNoteInfo(
        audioFile: 'voice-a.m4a',
        status: VoiceNoteStatus.transcribing,
      ),
    );

    expect(find.text('录音笔记'), findsOneWidget);
    expect(find.text('录音转写中…'), findsOneWidget);
    expect(find.textContaining('约需 10 秒 - 1 分钟'), findsOneWidget);
    expect(find.text('录音原文'), findsNothing);
    expect(find.text('笔记内容'), findsNothing);
  });

  testWidgets('转写失败：显示原因并可重试', (tester) async {
    await pump(
      tester,
      const VoiceNoteInfo(
        audioFile: 'voice-a.m4a',
        status: VoiceNoteStatus.failed,
        failureReason: '未配置语音识别模型',
      ),
    );

    expect(find.text('转写未完成'), findsOneWidget);
    expect(find.text('未配置语音识别模型'), findsOneWidget);
    expect(find.textContaining('原始录音已保留'), findsOneWidget);

    await tester.tap(find.text('重试转写'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('端侧完成：显示"本地未联网"+ 云端精修入口，不显示任何错误文案', (tester) async {
    var refined = 0;
    await pump(
      tester,
      const VoiceNoteInfo(
        audioFile: 'voice-a.m4a',
        status: VoiceNoteStatus.onDeviceDone,
        onDevice: true,
        noteText: '今天和客户对了报价。',
      ),
      onRefine: () => refined++,
    );

    expect(find.textContaining('端侧转写完成'), findsOneWidget);
    expect(find.textContaining('本地，未联网'), findsOneWidget);
    // 不该再出现任何"失败"字样（用户反馈的核心问题）
    expect(find.text('转写未完成'), findsNothing);
    expect(find.textContaining('处理未完成'), findsNothing);

    await tester.tap(find.text('云端精修'));
    await tester.pump();
    expect(refined, 1);
  });

  testWidgets('完成且有原文差异：出现两个 Tab，点击回调切换', (tester) async {
    await pump(
      tester,
      const VoiceNoteInfo(
        audioFile: 'voice-a.m4a',
        status: VoiceNoteStatus.done,
        rawText: '嗯那个就是明天给李总回电话',
        noteText: '明天给李总回电话。',
      ),
    );

    expect(find.text('录音原文'), findsOneWidget);
    expect(find.text('笔记内容'), findsOneWidget);

    await tester.tap(find.text('录音原文'));
    await tester.pump();
    expect(tabs, [VoiceNoteTab.raw]);
  });

  testWidgets('完成但原文与正文一致：不显示无意义的 Tab', (tester) async {
    await pump(
      tester,
      const VoiceNoteInfo(
        audioFile: 'voice-a.m4a',
        status: VoiceNoteStatus.done,
        rawText: '同一段文字',
        noteText: '同一段文字',
      ),
    );

    expect(find.text('录音原文'), findsNothing);
    expect(find.text('笔记内容'), findsNothing);
  });
}
