import 'dart:io';
import 'package:open_file/open_file.dart';

Future<void> saveBytesFile(String filename, List<int> bytes) async {
  final directory = Directory.systemTemp;
  final filePath = '${directory.path}/$filename';
  final file = File(filePath);
  await file.writeAsBytes(bytes);
  await OpenFile.open(filePath);
}
