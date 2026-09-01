import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/extract/ai_extract_meta.dart';
import 'package:moodiary/features/ai/extract/extract_cleanup_service.dart';
import 'package:moodiary/features/block/models/block.dart';
import 'package:moodiary/features/schedule/models/schedule.dart';
import 'package:moodiary/features/schedule/schedule_repository.dart';
import 'package:moodiary/persistence/app_database.dart';

import '../helpers/db_test_helper.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDb());
  tearDown(() => closeTestDb(db));

  test('onBlockDeleted 级联软删该块抽取生成的日程', () async {
    final repo = ScheduleRepository();
    final s = await repo.create(
      Schedule()
        ..title = '开会'
        ..startTime = DateTime(2026, 9, 1, 10)
        ..linkedDiaryId = 'd1',
    );
    final block = Block()
      ..id = 'b1'
      ..diaryId = 'd1'
      ..blockType = BlockType.text;
    AiExtractMeta.write(
      block,
      AiExtractMeta(
        scheduleIds: [s.id],
        crmProposals: const [],
      ),
    );

    await ExtractCleanupService().onBlockDeleted(block);
    final active = await repo.listActive();
    expect(active.map((e) => e.id), isNot(contains(s.id)));
  });

  test('onDiaryDeleted 软删所有 linkedDiaryId 的日程', () async {
    final repo = ScheduleRepository();
    await repo.create(
      Schedule()
        ..title = 'A'
        ..startTime = DateTime(2026, 9, 1, 10)
        ..linkedDiaryId = 'd1',
    );
    await repo.create(
      Schedule()
        ..title = 'B'
        ..startTime = DateTime(2026, 9, 2, 10)
        ..linkedDiaryId = 'd2',
    );

    await ExtractCleanupService().onDiaryDeleted('d1');
    final active = await repo.listActive();
    expect(active, hasLength(1));
    expect(active.first.linkedDiaryId, 'd2');
  });
}
