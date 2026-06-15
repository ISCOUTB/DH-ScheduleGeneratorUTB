// lib/widgets/layout/schedule_counter_badge.dart
import 'package:flutter/material.dart';

/// Badge flotante que muestra el conteo de horarios generados.
class ScheduleCounterBadge extends StatelessWidget {
  /// Número de horarios.
  final int count;

  /// Si la lista fue truncada por el cap móvil (muestra "N+").
  final bool truncated;

  const ScheduleCounterBadge({
    Key? key,
    required this.count,
    this.truncated = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$count${truncated ? "+" : ""} ${count == 1 ? "horario" : "horarios"}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
