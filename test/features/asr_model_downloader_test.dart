import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/asr/asr_model_downloader.dart';
import 'package:moodiary/features/asr/asr_model_store.dart';

void main() {
  group('AsrModelDownloader（模型下载源与进度）', () {
    test('三个核心文件都有候选下载源，且都是 https', () {
      for (final name in [
        AsrModelFiles.vad,
        AsrModelFiles.asr,
        AsrModelFiles.tokens,
      ]) {
        final urls = AsrModelDownloader.sources[name];
        expect(urls, isNotNull, reason: '$name 必须有下载源');
        expect(urls, isNotEmpty);
        for (final u in urls!) {
          expect(u.startsWith('https://'), isTrue, reason: '$u 应为 https');
        }
      }
    });

    test('大模型（227MB）不在下载源里（会在部分设备上让进程静默退出）', () {
      final all = AsrModelDownloader.sources.values
          .expand((e) => e)
          .join('\n');
      expect(all.contains('model_quant.onnx'), isFalse);
      expect(all.contains('speech_paraformer-large'), isFalse);
    });

    test('进度对象：有总长时给比例，无总长时不崩', () {
      const withTotal = AsrDownloadProgress(
        fileName: AsrModelFiles.asr,
        fileIndex: 2,
        fileCount: 3,
        received: 50,
        total: 100,
      );
      expect(withTotal.fraction, 0.5);
      expect(withTotal.label, contains('2/3'));
      expect(withTotal.detail, contains('MB'));

      const noTotal = AsrDownloadProgress(
        fileName: AsrModelFiles.vad,
        fileIndex: 1,
        fileCount: 1,
        received: 1024,
        total: 0,
      );
      expect(noTotal.fraction, isNull);
      expect(noTotal.detail, '0.0 MB');
    });

    test('比例被夹在 0..1（服务器给错总长也不越界）', () {
      const over = AsrDownloadProgress(
        fileName: 'x',
        fileIndex: 1,
        fileCount: 1,
        received: 200,
        total: 100,
      );
      expect(over.fraction, 1.0);
    });
  });
}
