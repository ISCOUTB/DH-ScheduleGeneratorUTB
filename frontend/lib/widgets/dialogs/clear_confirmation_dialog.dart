// lib/widgets/dialogs/clear_confirmation_dialog.dart
import 'package:flutter/material.dart';

/// Diálogo de confirmación para limpiar todos los datos.
class ClearConfirmationDialog extends StatelessWidget {
  /// Callback cuando el usuario confirma la acción.
  final VoidCallback onConfirm;

  const ClearConfirmationDialog({
    Key? key,
    required this.onConfirm,
  }) : super(key: key);

  /// Muestra el diálogo de confirmación.
  /// 
  /// Retorna `true` si el usuario confirmó, `false` si canceló.
  static Future<bool> show(BuildContext context, {required VoidCallback onConfirm}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ClearConfirmationDialog(onConfirm: onConfirm),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar acción'),
      content: const Text(
        '¿Estás seguro de que quieres limpiar todo? Esta acción no se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
            onConfirm();
          },
          child: const Text('Sí, limpiar todo'),
        ),
      ],
    );
  }
}
