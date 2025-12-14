// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
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

  /// Usuario actualmente autenticado.
  User? get currentUser => _currentUser;

  /// Indica si hay un usuario autenticado.
  bool get isAuthenticated => _currentUser != null;

  /// Verifica si hay una sesión activa y obtiene el usuario.
  /// 
  /// Retorna el usuario si hay sesión, null si no.
  Future<User?> checkSession() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/auth/me'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        _currentUser = User.fromJson(data);
        return _currentUser;
      } else {
        print('No hay sesión activa: ${response.statusCode}');
        _currentUser = null;
        return null;
      }
    } catch (e) {
      print('Error verificando sesión: $e');
      _currentUser = null;
      return null;
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
    
    try {
      // Enviar petición al backend para invalidar la sesión
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/auth/logout'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        microsoftLogoutUrl = data['microsoft_logout_url'];
      }
    } catch (e) {
      print('Error durante logout: $e');
    } finally {
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
