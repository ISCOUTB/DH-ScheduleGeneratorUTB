// lib/widgets/common/custom_notification.dart
import 'package:flutter/material.dart';

/// Muestra una notificación personalizada en un diálogo.
void showCustomNotification(
  BuildContext context,
  String message, {
  IconData? icon,
  Color? color,
}) {
  showDialog(
    context: context,
    builder: (context) => CustomNotificationDialog(
      message: message,
      icon: icon,
      color: color,
    ),
  );
}

/// Widget de diálogo para notificaciones personalizadas.
class CustomNotificationDialog extends StatelessWidget {
  final String message;
  final IconData? icon;
  final Color? color;

  const CustomNotificationDialog({
    Key? key,
    required this.message,
    this.icon,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, color: color ?? const Color(0xFF1ABC7B), size: 32),
            if (icon != null) const SizedBox(width: 16),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(fontSize: 18, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
