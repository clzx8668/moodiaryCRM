import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/ai/tasks/note_refresh_service.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  test('首页/详情页都没挂载时：安全空操作（后台任务可直接调用）', () async {
    // 后台 worker 里没有 UI，这里必须不抛异常
    await NoteRefreshService.afterWriteBack('d1');
    expect(true, isTrue);
  });
}
