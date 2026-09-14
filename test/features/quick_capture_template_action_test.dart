import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/prompts.dart';
import 'package:moodiary/features/ai/tasks/ai_task_repository.dart';
import 'package:moodiary/features/quick_capture/quick_capture_template_action.dart';

void main() {
  group('quickCaptureActionFor', () {
    test('待办走结构化抽取', () {
      final a = quickCaptureActionFor('待办');
      expect(a?.type, AiTaskType.extractPlan);
      expect(a?.payload, '');
    });

    test('其余模板走 ai_template 并带对应模板 id', () {
      expect(quickCaptureActionFor('扩写')?.payload, AiTemplates.expand);
      expect(quickCaptureActionFor('润色')?.payload, AiTemplates.polish);
      expect(quickCaptureActionFor('会议记录')?.payload, AiTemplates.meeting);
      expect(quickCaptureActionFor('翻译')?.payload, AiTemplates.translate);
      expect(quickCaptureActionFor('打卡')?.payload, AiTemplates.checkin);
      expect(quickCaptureActionFor('扩写')?.type, AiTaskType.aiTemplate);
    });

    test('未知/空模板不触发', () {
      expect(quickCaptureActionFor(''), isNull);
      expect(quickCaptureActionFor('未知模板'), isNull);
    });
  });
}
