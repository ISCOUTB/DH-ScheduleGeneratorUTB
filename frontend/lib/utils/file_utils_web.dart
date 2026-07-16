// lib/utils/file_utils_web.dart
import 'dart:typed_data';

// Importamos 'dart:html' solo si estamos en web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> saveAndOpenFile(Uint8List bytes, String filename) async {
  // MIME genérico a propósito: Safari (sobre todo en iOS) sabe renderizar
  // application/pdf, así que lo abría en línea y se llevaba la página en vez de
  // descargarlo. Con octet-stream no puede previsualizarlo y respeta la
  // descarga. El Excel nunca tuvo el problema justamente porque Safari no sabe
  // renderizar .xlsx. El tipo real lo deduce el sistema por la extensión.
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Safari exige que el <a> esté en el DOM para respetar el atributo download.
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  // Revocar de inmediato cortaba la descarga en Safari (carrera con el click).
  Future.delayed(const Duration(seconds: 1), () => html.Url.revokeObjectUrl(url));
}
