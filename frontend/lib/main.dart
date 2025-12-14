// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'config/theme.dart';
import 'models/user.dart';
import 'providers/schedule_provider.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

/// Punto de entrada principal de la aplicación.
void main() async {
  setPathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa Firebase para que funcione correctamente
  // para cualquier plataforma (web, android, ios).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

/// Widget raíz de la aplicación.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  /// Autenticación: verifica sesión existente o redirige al login.
  Future<void> _authenticate() async {
    final authService = AuthService();
    
    try {
      // Verificar si hay sesión activa (cookie de sesión)
      final user = await authService.checkSession();
      
      if (user != null) {
        // Sesión válida
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      } else {
        // No hay sesión, redirigir al login de Microsoft
        authService.login();
      }
    } catch (e) {
      debugPrint('Error en autenticación: $e');
      // En caso de error, redirigir al login
      AuthService().login();
    }
  }

  void _handleLogout() {
    AuthService().logout();
    // logout() ya redirige al login
  }

  @override
  Widget build(BuildContext context) {
    // Usamos un solo MaterialApp con ChangeNotifierProvider
    // para evitar problemas de reconstrucción del árbol de widgets.
    return ChangeNotifierProvider(
      create: (_) => ScheduleProvider(),
      child: MaterialApp(
        title: 'Generador de Horarios UTB',
        navigatorKey: navigatorKey,
        scrollBehavior: WebScrollBehavior(),
        theme: AppTheme.lightTheme,
        home: _buildHome(),
      ),
    );
  }

  /// Construye la pantalla principal según el estado de autenticación.
  Widget _buildHome() {
    // Mientras carga o no hay usuario, mostrar indicador de carga.
    // La redirección a Microsoft ocurre automáticamente si no hay sesión.
    if (_isLoading || _currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return HomeScreen(
      title: 'Generador de Horarios UTB',
      currentUser: _currentUser!,
      onLogout: _handleLogout,
    );
  }
}