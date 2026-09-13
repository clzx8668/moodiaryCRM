import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/ai/autolink/semantic_link_service.dart';

void main() {
  group('SemanticLinkService', () {
    test('rankByVectors 按余弦降序且过滤低相似', () {
      final target = Float32List.fromList([1, 0, 0]);
      final vectors = {
        'a': Float32List.fromList([1, 0, 0]), // 1.0
        'b': Float32List.fromList([0.9, 0.1, 0]), // ~0.994
        'c': Float32List.fromList([0, 1, 0]), // 0.0
      };
      final result = SemanticLinkService.rankByVectors(target, vectors);
      expect(result.first.id, 'a');
      expect(result.map((e) => e.id), contains('b'));
      expect(result.map((e) => e.id), isNot(contains('c')));
    });

    test('维度不一致或空向量跳过', () {
      final result = SemanticLinkService.rankByVectors(
        Float32List.fromList([1, 0]),
        {
          'x': Float32List.fromList([1, 0, 0]),
          'y': Float32List.fromList(const []),
        },
      );
      expect(result, isEmpty);
    });

    test('topK 截断', () {
      final target = Float32List.fromList([1, 0]);
      final vectors = {
        'a': Float32List.fromList([1, 0]),
        'b': Float32List.fromList([1, 0.01]),
        'c': Float32List.fromList([1, 0.02]),
      };
      final result = SemanticLinkService.rankByVectors(
        target,
        vectors,
        topK: 2,
      );
      expect(result.length, 2);
    });

    test('embedText 拼接标题与正文', () {
      expect(SemanticLinkService.embedText('标题', '正文'), '标题\n正文');
      expect(SemanticLinkService.embedText('', '正文'), '正文');
      expect(SemanticLinkService.embedText('标题', ''), '标题');
    });
  });
}
