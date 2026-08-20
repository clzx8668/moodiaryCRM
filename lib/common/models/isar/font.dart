import 'package:path/path.dart';

class Font {
  final String fontFileName;

  // 兼容旧接口：文件名哈希（Drift 主键为 fontFileName 字符串）
  int get id => fastHash(fontFileName);

  String get fontFamily => basenameWithoutExtension(fontFileName);

  String get fontType => extension(fontFileName);

  final Map<String, dynamic> fontWghtAxisMap;

  Font({required this.fontFileName, required this.fontWghtAxisMap});
}

int fastHash(String string) {
  var hash = 0xcbf29ce484222325;
  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}
