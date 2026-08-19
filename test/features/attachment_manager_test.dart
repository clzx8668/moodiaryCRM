import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/attachments/attachment_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late Directory sourceDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('attachments_test');
    sourceDir = await Directory.systemTemp.createTemp('attachments_src');
    AttachmentManager.setBaseDirForTest(tempDir.path);
  });

  tearDown(() async {
    AttachmentManager.resetBaseDirForTest();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await sourceDir.exists()) {
      await sourceDir.delete(recursive: true);
    }
  });

  test('保存文件到 Attachments/Documents/YYYY/MM 并返回相对路径', () async {
    final source = File(p.join(sourceDir.path, 'src.pdf'));
    await source.writeAsString('pdf-content');

    final rel = await AttachmentManager.saveFile(
      sourcePath: source.path,
      category: 'documents',
    );

    expect(rel, startsWith('Documents/'));
    expect(rel, isNot(contains('\\')));
    final now = DateTime.now();
    expect(
      rel,
      startsWith(
        'Documents/${now.year}/${now.month.toString().padLeft(2, '0')}/',
      ),
    );
    final resolved = File(
      p.joinAll([tempDir.path, ...p.split(rel)]),
    );
    expect(await resolved.exists(), isTrue);
    expect(await resolved.readAsString(), 'pdf-content');
  });

  test('metadata.json 登记引用', () async {
    final source = File(p.join(sourceDir.path, 'a.jpg'));
    await source.writeAsString('img');
    final rel = await AttachmentManager.saveFile(
      sourcePath: source.path,
      category: 'images',
    );

    await AttachmentManager.addReference(
      rel,
      diaryId: 'd1',
      blockId: 'b1',
    );

    final metas = await AttachmentManager.loadMetadata();
    expect(metas, hasLength(1));
    expect(metas.first.relativePath, rel);
    expect(metas.first.diaryId, 'd1');
    expect(metas.first.blockId, 'b1');
  });

  test('孤立文件扫描与清理', () async {
    // 登记一个文件
    final source = File(p.join(sourceDir.path, 'known.pdf'));
    await source.writeAsString('known');
    final rel = await AttachmentManager.saveFile(
      sourcePath: source.path,
      category: 'documents',
    );
    await AttachmentManager.addReference(rel);

    // 手动放一个未登记文件
    final orphanDir = Directory(
      p.join(tempDir.path, 'Documents', '2026', '08'),
    );
    await orphanDir.create(recursive: true);
    final orphan = File(p.join(orphanDir.path, 'orphan.pdf'));
    await orphan.writeAsString('orphan');

    final orphans = await AttachmentManager.scanOrphans();
    expect(orphans, hasLength(1));
    expect(orphans.first, orphan.path);

    final cleaned = await AttachmentManager.cleanOrphans();
    expect(cleaned, 1);
    expect(await orphan.exists(), isFalse);
    expect(await File(p.joinAll([tempDir.path, ...p.split(rel)])).exists(), isTrue);
  });
}
