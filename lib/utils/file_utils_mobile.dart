// lib/utils/file_utils_mobile.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'storage_permissions.dart';

Future<void> saveAndOpenFile(Uint8List bytes, String filename) async {
  try {
    // Solicitar permisos de almacenamiento
    await requestStoragePermission();

    // Obtener la ruta para guardar el archivo
    final path = await getFilePath(filename);

    // Guardar el archivo
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    // Abrir el archivo
    await OpenFile.open(file.path);

    print('Archivo guardado en: ${file.path}');
  } catch (e) {
    print('Error al guardar y abrir el archivo: $e');
  }
}

Future<String> getFilePath(String fileName) async {
  Directory directory;

  if (Platform.isAndroid) {
    directory = (await getExternalStorageDirectory())!;
    String newPath = "";
    List<String> folders = directory.path.split("/");
    for (int x = 1; x < folders.length; x++) {
      String folder = folders[x];
      if (folder != "Android") {
        newPath += "/" + folder;
      } else {
        break;
      }
    }
    newPath = newPath + "/Download";
    directory = Directory(newPath);
  } else {
    directory = await getApplicationDocumentsDirectory();
  }

  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  // Aquí es donde verificamos si el archivo existe y generamos un nombre único
  String filePath = '${directory.path}/$fileName';
  filePath = await _getUniqueFilePath(filePath);

  return filePath;
}

Future<String> _getUniqueFilePath(String filePath) async {
  String pathWithoutExtension =
      filePath.substring(0, filePath.lastIndexOf('.'));
  String extension = filePath.substring(filePath.lastIndexOf('.'));
  int fileNumber = 1;

  while (await File(filePath).exists()) {
    filePath = '${pathWithoutExtension}(${fileNumber.toString()})$extension';
    fileNumber++;
  }

  return filePath;
}
