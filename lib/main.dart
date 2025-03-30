// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'Screens/home_desktop.dart'; // Ruta para llamar UI de computador
import 'Screens/home_mobile.dart'; // Ruta para llamar UI de móvil

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ThemeData(
      primarySwatch: Colors.indigo,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.indigo,
        accentColor: Colors.amber,
        brightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'Generador de Horarios UTB',
      theme: theme,
      home: const PlatformAdaptiveHomePage(title: 'Generador de Horarios UTB'),
    );
  }
}

class PlatformAdaptiveHomePage extends StatelessWidget {
  final String title;

  const PlatformAdaptiveHomePage({super.key, required this.title});

  bool isMobile() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    return isMobile() ? HomeMobile(title: title) : HomeDesktop(title: title);
  }
}
