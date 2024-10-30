// lib/utils/file_utils_web.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Para kIsWeb

// Importamos 'dart:html' solo si estamos en web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> saveAndOpenFile(Uint8List bytes, String filename) async {
  // Solo se ejecuta en web
  final mimeType = filename.endsWith('.pdf')
      ? 'application/pdf'
      : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
