import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/share/share_receiver.dart';

void main() {
  group('ShareReceiver.extractUrl', () {
    test('纯链接原样返回', () {
      expect(
        ShareReceiver.extractUrl('https://example.com/a'),
        'https://example.com/a',
      );
    });

    test('从分享文案中提取链接', () {
      expect(
        ShareReceiver.extractUrl('分享给你 https://b23.tv/abc 很好看'),
        'https://b23.tv/abc',
      );
    });

    test('去掉结尾标点', () {
      expect(
        ShareReceiver.extractUrl('看这个 https://a.com/x，。'),
        'https://a.com/x',
      );
      expect(
        ShareReceiver.extractUrl('(https://a.com/y)'),
        'https://a.com/y',
      );
    });

    test('无链接返回 null', () {
      expect(ShareReceiver.extractUrl('今天心情不错'), isNull);
      expect(ShareReceiver.extractUrl(''), isNull);
    });
  });

  group('ShareReceiver.normalizeShortcutId（长按图标快捷方式）', () {
    test('三个已知入口原样返回', () {
      expect(ShareReceiver.normalizeShortcutId('voice'), 'voice');
      expect(ShareReceiver.normalizeShortcutId('camera'), 'camera');
      expect(ShareReceiver.normalizeShortcutId('note'), 'note');
    });

    test('大小写与空白容错', () {
      expect(ShareReceiver.normalizeShortcutId(' VOICE '), 'voice');
      expect(ShareReceiver.normalizeShortcutId('Note'), 'note');
    });

    test('未知 / 空 → 空串（不误触发）', () {
      expect(ShareReceiver.normalizeShortcutId('unknown'), '');
      expect(ShareReceiver.normalizeShortcutId(''), '');
      expect(ShareReceiver.normalizeShortcutId(null), '');
    });

    test('常量与 shortcuts.xml 对齐', () {
      expect(ShareReceiver.shortcutVoice, 'voice');
      expect(ShareReceiver.shortcutCamera, 'camera');
      expect(ShareReceiver.shortcutNote, 'note');
    });
  });

  group('ShareReceiver 分享文件分类（多图 / 文档）', () {
    test('按扩展名区分图片与文档', () {
      final split = ShareReceiver.classifySharedPaths([
        '/tmp/a.jpg',
        '/tmp/b.PNG',
        '/tmp/c.pdf',
        '/tmp/d.docx',
        '/tmp/noext',
      ]);
      expect(split.images, ['/tmp/a.jpg', '/tmp/b.PNG']);
      expect(split.documents, ['/tmp/c.pdf', '/tmp/d.docx', '/tmp/noext']);
    });

    test('多附件速记正文按类型计数', () {
      expect(
        ShareReceiver.multiShareText(images: 3, documents: 0),
        '（分享保存：3 张图片）',
      );
      expect(
        ShareReceiver.multiShareText(images: 2, documents: 1),
        '（分享保存：2 张图片 + 1 个文档）',
      );
      expect(
        ShareReceiver.multiShareText(images: 0, documents: 1),
        '（分享保存：1 个文档）',
      );
      expect(ShareReceiver.multiShareText(images: 0, documents: 0), '来自分享的附件');
    });
  });
}
