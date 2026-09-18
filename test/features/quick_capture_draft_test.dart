import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/quick_capture/quick_capture_draft.dart';
import 'package:moodiary/features/quick_capture/quick_capture_state.dart';

void main() {
  group('QuickCaptureDraft 临时记忆（JSON 往返）', () {
    test('文本 / 模板 / 附件完整往返', () {
      const draft = QuickCaptureDraft(
        text: '还没写完的一句话',
        template: '待办',
        attachments: [
          QuickAttachment(
            path: '/data/audio/a.m4a',
            type: QuickAttachmentType.audio,
            name: 'a.m4a',
          ),
          QuickAttachment(
            path: '/data/image/b.jpg',
            type: QuickAttachmentType.image,
            name: 'b.jpg',
          ),
        ],
      );
      final restored = QuickCaptureDraft.fromJson(draft.toJson())!;
      expect(restored.text, '还没写完的一句话');
      expect(restored.template, '待办');
      expect(restored.attachments, hasLength(2));
      expect(restored.attachments.first.type, QuickAttachmentType.audio);
      expect(restored.attachments[1].path, '/data/image/b.jpg');
    });

    test('空草稿判定：全空 / 仅空白文本', () {
      expect(const QuickCaptureDraft().isEmpty, isTrue);
      expect(const QuickCaptureDraft(text: '   ').isEmpty, isTrue);
      expect(const QuickCaptureDraft(text: 'a').isEmpty, isFalse);
      expect(
        const QuickCaptureDraft(
          attachments: [
            QuickAttachment(
              path: '/x.jpg',
              type: QuickAttachmentType.image,
              name: 'x.jpg',
            ),
          ],
        ).isEmpty,
        isFalse,
      );
    });

    test('容错：脏 JSON / 缺字段 / 未知附件类型', () {
      expect(QuickCaptureDraft.fromJson(null), isNull);
      expect(QuickCaptureDraft.fromJson({'text': 123})!.text, '123');
      final restored = QuickCaptureDraft.fromJson({
        'attachments': [
          {'path': '/a.bin', 'type': 'unknown-type', 'name': ''},
          {'path': '', 'type': 'image', 'name': 'ignored'},
        ],
      })!;
      expect(restored.attachments, hasLength(1));
      expect(restored.attachments.first.type, QuickAttachmentType.other);
      expect(restored.attachments.first.name, 'a.bin');
    });
  });
}
