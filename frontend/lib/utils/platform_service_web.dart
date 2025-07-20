// /frontend/lib/utils/platform_service_web.dart
import 'package:web/web.dart' as web;

/// Implementación del servicio de plataforma específico para la web.
class PlatformService {
  /// Verifica el User Agent del navegador para detectar si es un dispositivo móvil.
  bool isMobileUserAgent() {
    final userAgent = web.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('mobi') ||
        userAgent.contains('android') ||
        userAgent.contains('iphone') ||
        userAgent.contains('ipad');
  }

  /// Obtiene un valor del localStorage del navegador.
  String? getLocalStorage(String key) {
    return web.window.localStorage.getItem(key);
  }

  /// Establece un valor en el localStorage del navegador.
  void setLocalStorage(String key, String value) {
    web.window.localStorage.setItem(key, value);
  }
}
