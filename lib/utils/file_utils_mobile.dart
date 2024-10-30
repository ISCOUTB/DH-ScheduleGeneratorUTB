// lib/utils/file_utils_mobile.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

Future<void> saveAndOpenFile(Uint8List bytes, String filename) async {
  // Obtener el directorio de documentos
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/$filename';

  // Guardar el archivo
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  // Abrir el archivo
  await OpenFile.open(filePath);
}
