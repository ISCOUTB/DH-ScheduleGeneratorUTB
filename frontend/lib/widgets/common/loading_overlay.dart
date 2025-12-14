// lib/widgets/common/loading_overlay.dart
import 'package:flutter/material.dart';

/// Overlay de carga que cubre toda la pantalla.
class LoadingOverlay extends StatelessWidget {
  /// Mensaje a mostrar durante la carga.
  final String message;

  const LoadingOverlay({
    Key? key,
    this.message = 'Cargando...',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
