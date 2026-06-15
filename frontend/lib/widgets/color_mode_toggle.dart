// lib/widgets/color_mode_toggle.dart
import 'package:flutter/material.dart';

/// Toggle compacto "Materia ↔ Estado" de cupos.
///
/// Reutilizado por la pantalla de horarios destacados y por el detalle de un
/// horario. No tiene estado propio: el padre decide qué segmento está activo y
/// reacciona a [onChanged].
class ColorModeToggle extends StatelessWidget {
  /// true => segmento "Estado" activo; false => "Materia".
  final bool statusSelected;

  /// Si el segmento "Estado" se puede seleccionar (p. ej. solo en el término
  /// actual). Cuando es false, "Estado" se ve deshabilitado.
  final bool statusEnabled;

  /// Notifica el nuevo modo: true = estado, false = materia.
  final ValueChanged<bool> onChanged;

  /// Si los dos segmentos se apilan en vertical (Materia arriba, Estado abajo)
  /// en vez de lado a lado. Útil en pantallas angostas (detalle móvil).
  final bool vertical;

  const ColorModeToggle({
    super.key,
    required this.statusSelected,
    required this.statusEnabled,
    required this.onChanged,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final segments = [
      _segment(
        label: 'Materia',
        icon: Icons.palette_outlined,
        selected: !statusSelected,
        enabled: true,
        onTap: () => onChanged(false),
      ),
      _segment(
        label: 'Estado',
        icon: Icons.event_seat_outlined,
        selected: statusSelected,
        enabled: statusEnabled,
        onTap: statusEnabled ? () => onChanged(true) : null,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: vertical
          // IntrinsicWidth acota el ancho al del segmento más ancho, para que
          // `stretch` funcione (si no, el Column queda sin ancho definido al
          // ser hijo no-flex de un Row → "render box with no size").
          ? IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: segments,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: segments,
            ),
    );
  }

  Widget _segment({
    required String label,
    required IconData icon,
    required bool selected,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    const blue = Color(0xFF2742F5);
    final fg = selected
        ? Colors.white
        : (enabled ? const Color(0xFF6B7280) : const Color(0xFFB0B6BE));

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? blue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }
}
