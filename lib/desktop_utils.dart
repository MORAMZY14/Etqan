import 'dart:io' as io;

Future<void> saveFile(String path, String content) async {
  final file = io.File(path);
  await file.writeAsString(content);
}
