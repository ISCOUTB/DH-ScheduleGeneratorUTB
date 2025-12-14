// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'package:universal_html/html.dart' as html;
import '../models/user.dart';

/// Clave global para el navegador (mantenida por compatibilidad con main.dart).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Servicio de autenticación con Microsoft Entra ID.
/// 
/// Usa el flujo OAuth manejado desde el backend:
/// 1. Frontend llama a /api/auth/me para verificar sesión
/// 2. Si no hay sesión, redirige a /api/auth/login
/// 3. Backend maneja todo el flujo OAuth con Microsoft
/// 4. Backend retorna con cookie de sesión
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // URL base del backend (nginx en puerto 80 hace proxy a /api/*)
  static const String _apiBaseUrl = kDebugMode 
      ? 'http://localhost' 
      : '';  // En producción usa rutas relativas

  User? _currentUser;

  /// Crea un cliente HTTP que envía cookies (necesario para web).
  http.Client _createClient() {
    if (kIsWeb) {
      final client = BrowserClient();
      client.withCredentials = true;
      return client;
    }
    return http.Client();
  }

  /// Usuario actualmente autenticado.
  User? get currentUser => _currentUser;

  /// Indica si hay un usuario autenticado.
  bool get isAuthenticated => _currentUser != null;

  /// Verifica si hay una sesión activa y obtiene el usuario.
  /// 
  /// Retorna el usuario si hay sesión, null si no.
  Future<User?> checkSession() async {
    final client = _createClient();
    try {
      final response = await client.get(
        Uri.parse('$_apiBaseUrl/api/auth/me'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final bodyString = utf8.decode(response.bodyBytes);
        final data = json.decode(bodyString);
        _currentUser = User.fromJson(data);
        return _currentUser;
      } else {
        _currentUser = null;
        return null;
      }
    } catch (e) {
      debugPrint('Error verificando sesión: $e');
      _currentUser = null;
      return null;
    } finally {
      client.close();
    }
  }

  /// Redirige al usuario a la página de login de Microsoft.
  void login() {
    // Redirigir al endpoint de login del backend
    // El backend se encarga de redirigir a Microsoft
    final loginUrl = '$_apiBaseUrl/api/auth/login';
    html.window.location.href = loginUrl;
  }

  /// Cierra la sesión del usuario.
  Future<void> logout() async {
    String? microsoftLogoutUrl;
    final client = _createClient();
    
    try {
      // Enviar petición al backend para invalidar la sesión
      final response = await client.post(
        Uri.parse('$_apiBaseUrl/api/auth/logout'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        microsoftLogoutUrl = data['microsoft_logout_url'];
      }
    } catch (e) {
      debugPrint('Error durante logout: $e');
    } finally {
      client.close();
      _currentUser = null;
    }
    
    // Redirigir a Microsoft logout para cerrar sesión completamente
    // Esto evita que Microsoft re-autentique automáticamente
    if (microsoftLogoutUrl != null) {
      html.window.location.href = microsoftLogoutUrl;
    } else {
      // Fallback: recargar la página
      html.window.location.reload();
    }
  }

  /// Obtiene headers para peticiones autenticadas.
  /// Con cookies, no necesitamos enviar token manualmente.
  Map<String, String> getAuthHeaders() {
    return {'Content-Type': 'application/json'};
  }
}
