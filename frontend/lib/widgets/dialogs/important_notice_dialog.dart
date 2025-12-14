// lib/widgets/dialogs/important_notice_dialog.dart
import 'package:flutter/material.dart';
import '../../config/constants.dart';

/// Diálogo de aviso importante que se muestra al iniciar la aplicación.
/// 
/// Advierte a los usuarios que verifiquen la información en Banner
/// antes de tomar decisiones basadas en los horarios generados.
class ImportantNoticeDialog extends StatelessWidget {
  /// Callback cuando el usuario presiona "Entendido".
  final VoidCallback onDismiss;

  const ImportantNoticeDialog({
    Key? key,
    required this.onDismiss,
  }) : super(key: key);

  /// Muestra el diálogo de aviso importante.
  static Future<void> show(BuildContext context, {required VoidCallback onDismiss}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImportantNoticeDialog(onDismiss: onDismiss),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning,
            color: Colors.red.shade600,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            'IMPORTANTE',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Text(
          'Antes de tomar decisiones basadas en un horario generado, te recomendamos verificar la información directamente en Banner, ya que este generador es una herramienta de apoyo y la fuente oficial de horarios, NRC y disponibilidad es Banner.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
          textAlign: TextAlign.justify,
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            onDismiss();
            Navigator.of(context).pop();
          },
          child: const Text(
            'Entendido',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
