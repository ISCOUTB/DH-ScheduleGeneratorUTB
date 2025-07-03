import 'dart:convert';
import 'dart:html' as html;

class AuthService {
  static const _tenantId = '1ae0c106-3b63-42fd-9149-52d736399d5a';
  static const _clientId = 'de6b5a9b-9cdf-4484-ba51-aa45bf431e52';
  static const _redirectUri = 'http://localhost:5173/auth';

  String? getUserNameFromToken() {
    final token = html.window.localStorage['id_token'];
    if (token == null) return null;

    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      final payloadMap = json.decode(decoded);
      return payloadMap['name'] ?? payloadMap['preferred_username'];
    } catch (e) {
      return null;
    }
  }

  bool isUserLoggedIn() {
    return html.window.localStorage['id_token'] != null;
  }

  void login() {
    final authUrl =
        'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/authorize'
        '?client_id=$_clientId'
        '&response_type=id_token'
        '&redirect_uri=$_redirectUri'
        '&response_mode=fragment'
        '&scope=openid email profile'
        '&nonce=abc123'
        '&state=xyz456';

    html.window.location.href = authUrl;
  }

  void logout() {
    html.window.localStorage.remove('id_token');
    login(); // Redirige al login después de cerrar sesión
  }
}
