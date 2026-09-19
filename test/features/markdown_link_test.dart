import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/attachments/attachment_manager.dart';
import 'package:moodiary/features/block/markdown_link.dart';
import 'package:path/path.dart' as p;

void main() {
  setUp(() => AttachmentManager.setBaseDirForTest('/tmp/attachments'));
  tearDown(AttachmentManager.resetBaseDirForTest);

  group('链接类型判定', () {
    test('http(s) 与 mailto 走外链', () {
      expect(MarkdownLink.kindOf('https://a.com/x'), MarkdownLinkKind.external);
      expect(MarkdownLink.kindOf('http://a.com'), MarkdownLinkKind.external);
      expect(MarkdownLink.kindOf('mailto:a@b.com'), MarkdownLinkKind.external);
    });

    test('相对路径（正文里的附件）判定为本地', () {
      expect(
        MarkdownLink.kindOf('documents/2026/09/a.pdf'),
        MarkdownLinkKind.local,
      );
      expect(
        MarkdownLink.kindOf('Documents/2026/09/a.docx'),
        MarkdownLinkKind.local,
      );
    });

    test('空串为无效', () {
      expect(MarkdownLink.kindOf(''), MarkdownLinkKind.invalid);
      expect(MarkdownLink.kindOf('   '), MarkdownLinkKind.invalid);
    });
  });

  group('本地附件路径解析', () {
    test('相对路径 → 附件根目录下的绝对路径', () {
      final path = MarkdownLink.localPathOf('documents/2026/09/a.pdf');
      expect(path, isNotNull);
      expect(
        path,
        p.join('/tmp/attachments', 'documents', '2026', '09', 'a.pdf'),
      );
    });

    test('file:// 前缀与多余斜杠容错', () {
      expect(
        MarkdownLink.localPathOf('file://documents/2026/09/a.pdf'),
        p.join('/tmp/attachments', 'documents', '2026', '09', 'a.pdf'),
      );
      expect(
        MarkdownLink.localPathOf('/documents/2026/09/a.pdf'),
        p.join('/tmp/attachments', 'documents', '2026', '09', 'a.pdf'),
      );
    });

    test('外链不解析为本地路径', () {
      expect(MarkdownLink.localPathOf('https://a.com/x'), isNull);
      expect(MarkdownLink.localPathOf(''), isNull);
    });
  });
}
