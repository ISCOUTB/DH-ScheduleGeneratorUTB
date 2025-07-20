// frontend/lib/utils/platform_service_stub.dart
/// Implementación base (stub) para plataformas web.
class PlatformService {
  /// En plataformas no web, la detección de móvil se basa en el TargetPlatform.
  bool isMobileUserAgent() => false;

  /// No hay localStorage, por lo que siempre devuelve null.
  String? getLocalStorage(String key) => null;

  /// No hay localStorage, por lo que no hace nada.
  void setLocalStorage(String key, String value) {
    // No-op
  }
}
