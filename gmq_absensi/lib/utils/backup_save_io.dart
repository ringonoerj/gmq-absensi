import 'dart:io';
import 'package:open_file/open_file.dart';

Future<void> saveBackupFile(String filename, String jsonContent) async {
  final directory = Directory.current;
  final filePath = '${directory.path}/$filename';
  final file = File(filePath);
  await file.writeAsString(jsonContent);
  await OpenFile.open(filePath);
}
