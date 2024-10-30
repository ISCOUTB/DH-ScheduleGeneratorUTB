// lib/utils/file_utils.dart
export 'file_utils_stub.dart' // Definición por defecto
    if (dart.library.io) 'file_utils_mobile.dart' // Plataformas móviles y desktop
    if (dart.library.html) 'file_utils_web.dart'; // Web
