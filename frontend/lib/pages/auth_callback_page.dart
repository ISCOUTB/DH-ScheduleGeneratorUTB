import 'package:flutter/material.dart';

class AuthCallbackPage extends StatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  State<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  @override
  Widget build(BuildContext context) {
    // El script en index.html ahora maneja toda la lógica de autenticación.
    // Esta página solo necesita mostrar un mensaje de carga mientras
    // el script redirige al usuario.
    return const Scaffold(
      body: Center(
        child: Text(
          'Procesando inicio de sesión…',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
