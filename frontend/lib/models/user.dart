// lib/models/user.dart

/// Modelo que representa a un usuario autenticado.
class User {
  final int id;
  final String email;
  final String? nombre;
  final bool authenticated;

  User({
    required this.id,
    required this.email,
    this.nombre,
    this.authenticated = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      nombre: json['nombre'],
      authenticated: json['authenticated'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nombre': nombre,
      'authenticated': authenticated,
    };
  }

  /// Obtiene el nombre para mostrar (nombre completo o email).
  String get displayName => nombre ?? email;

  /// Obtiene las iniciales del usuario para avatares.
  String get initials {
    if (nombre != null && nombre!.isNotEmpty) {
      final parts = nombre!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return nombre![0].toUpperCase();
    }
    return email[0].toUpperCase();
  }
}
