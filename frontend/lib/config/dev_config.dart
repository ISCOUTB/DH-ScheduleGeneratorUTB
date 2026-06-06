// lib/config/dev_config.dart
import 'package:flutter/foundation.dart';

import '../models/user.dart';

/// Configuración exclusiva de **desarrollo**.
///
/// Estas opciones solo tienen efecto cuando se compila con los
/// `--dart-define` correspondientes Y en modo debug. Un build de producción
/// (`flutter build web --release` sin defines) las deja siempre en `false`,
/// por lo que no pueden usarse para saltarse la autenticación real.
class DevConfig {
  DevConfig._();

  // Valor del flag inyectado en tiempo de compilación.
  static const bool _skipAuthFlag =
      bool.fromEnvironment('DEV_SKIP_AUTH', defaultValue: false);

  /// Salta el flujo de autenticación con Microsoft Entra ID y usa un
  /// [mockUser] simulado. Pensado para iterar sobre la interfaz sin tener
  /// que autenticarse (o sin backend).
  ///
  /// Doble candado de seguridad: solo se activa si el flag está presente
  /// **y** la app corre en modo debug. En release siempre es `false`.
  ///
  /// Activar con:
  /// ```
  /// flutter run -d chrome --dart-define=DEV_SKIP_AUTH=true
  /// ```
  static bool get skipAuth => kDebugMode && _skipAuthFlag;

  /// Usuario simulado que se inyecta cuando [skipAuth] está activo.
  static User get mockUser => User(
        id: 'dev-mock-user',
        email: 'dev@utb.edu.co',
        nombre: 'Dev Local',
        authenticated: true,
      );
}
