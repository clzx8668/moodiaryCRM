import 'dart:convert';

/// Quill Delta JSON → Markdown 转换器
///
/// 架构决策（2026-08-19）：全局放弃 flutter_quill 富文本，
/// 内容统一为 Markdown，历史 Delta 数据迁移时调用本转换器。
class DeltaToMarkdown {
  /// 若 [content] 是 Delta JSON 数组则转换为 Markdown，否则原样返回。
  static String convertIfDelta(String content) {
    final ops = _tryParseDelta(content);
    if (ops == null) return content;
    return convertOps(ops);
  }

  static String convert(String deltaJson) {
    final ops = _tryParseDelta(deltaJson);
    if (ops == null) return deltaJson;
    return convertOps(ops);
  }

  static List<Map<String, dynamic>>? _tryParseDelta(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith('[')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return null;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  static String convertOps(List<Map<String, dynamic>> ops) {
    final buffer = StringBuffer();
    final line = StringBuffer();
    var lineAttrs = <String, dynamic>{};
    var inCodeBlock = false;
    final codeLines = <String>[];

    void flushLine() {
      if (inCodeBlock) {
        codeLines.add(line.toString());
        line.clear();
        return;
      }
      final text = line.toString();
      line.clear();
      if (text.isEmpty && lineAttrs.isEmpty) {
        lineAttrs = {};
        return;
      }
      final header = lineAttrs['header'];
      final list = lineAttrs['list'];
      final blockquote = lineAttrs['blockquote'] == true;
      final codeBlock = lineAttrs['code-block'] == true;
      if (codeBlock) {
        buffer.writeln('```');
        buffer.writeln(text);
        buffer.writeln('```');
      } else if (header is int && header >= 1 && header <= 6) {
        buffer.writeln('${'#' * header} $text');
      } else if (list == 'bullet') {
        buffer.writeln('- $text');
      } else if (list == 'ordered') {
        buffer.writeln('1. $text');
      } else if (blockquote) {
        buffer.writeln('> $text');
      } else {
        buffer.writeln(text);
      }
      lineAttrs = {};
    }

    void toggleCodeBlock() {
      if (!inCodeBlock) {
        // 结束当前行并进入代码块
        if (line.toString().trim().isNotEmpty) {
          flushLine();
        }
        inCodeBlock = true;
        codeLines.clear();
      } else {
        // 结束代码块
        if (line.toString().isNotEmpty) {
          codeLines.add(line.toString());
          line.clear();
        }
        while (codeLines.isNotEmpty && codeLines.last.isEmpty) {
          codeLines.removeLast();
        }
        if (codeLines.isNotEmpty) {
          buffer.writeln('```');
          buffer.writeln(codeLines.join('\n'));
          buffer.writeln('```');
          codeLines.clear();
        }
        inCodeBlock = false;
      }
    }

    for (final op in ops) {
      final insert = op['insert'];
      final attrs =
          (op['attributes'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      if (insert is Map) {
        if (inCodeBlock) {
          line.write('[嵌入]');
          continue;
        }
        if (insert.containsKey('image')) {
          final name = insert['image'].toString();
          line.write('![]($name)');
        } else if (insert.containsKey('video')) {
          final name = insert['video'].toString();
          line.write('[视频]($name)');
        } else if (insert.containsKey('audio')) {
          final name = insert['audio'].toString();
          line.write('[音频]($name)');
        } else {
          line.write('[嵌入]');
        }
        continue;
      }

      if (insert is! String) continue;

      if (attrs['code-block'] == true) {
        toggleCodeBlock();
        if (inCodeBlock) {
          // 代码块内容
          final parts = insert.split('\n');
          for (var i = 0; i < parts.length; i++) {
            if (i > 0) {
              codeLines.add(line.toString());
              line.clear();
            }
            if (parts[i].isNotEmpty) line.write(parts[i]);
          }
        }
        // 进入/退出代码块的换行 op 都不再走普通文本段
        continue;
      }

      if (inCodeBlock) {
        final parts = insert.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (i > 0) {
            codeLines.add(line.toString());
            line.clear();
          }
          if (parts[i].isNotEmpty) line.write(parts[i]);
        }
        continue;
      }

      // 普通文本：按换行切分；每个换行边界以本 op 属性终结当前行
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) {
          lineAttrs = attrs;
          flushLine();
          lineAttrs = {};
        }
        if (parts[i].isNotEmpty) {
          line.write(_renderInline(parts[i], attrs));
        }
      }
    }

    // 收尾
    if (inCodeBlock) {
      if (codeLines.isNotEmpty || line.toString().isNotEmpty) {
        buffer.writeln('```');
        buffer.writeln(codeLines.join('\n'));
        if (line.toString().isNotEmpty) buffer.writeln(line.toString());
        buffer.writeln('```');
      }
    } else if (line.toString().isNotEmpty || lineAttrs.isNotEmpty) {
      flushLine();
    }

    return buffer.toString().trimRight();
  }

  static String _renderInline(String text, Map<String, dynamic> attrs) {
    var result = text;
    if (attrs['code'] == true) {
      return '`$result`';
    }
    if (attrs['bold'] == true) {
      result = '**$result**';
    }
    if (attrs['italic'] == true) {
      result = '*$result*';
    }
    if (attrs['strike'] == true) {
      result = '~~$result~~';
    }
    final link = attrs['link'];
    if (link is String && link.isNotEmpty) {
      result = '[$result]($link)';
    }
    return result;
  }
}
