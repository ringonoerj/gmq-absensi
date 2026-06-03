import 'dart:html' as html;
import 'dart:convert';

Future<void> saveBackupFile(String filename, String jsonContent) async {
  final bytes = utf8.encode(jsonContent);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
