import 'package:flutter/material.dart';

/// Un panel que contiene los botones de acción principales de la aplicación.
///
/// Incluye acciones para buscar materias, aplicar filtros, limpiar la selección
/// y generar los horarios.
class MainActionsPanel extends StatelessWidget {
  /// Callback para la acción de buscar materia.
  final VoidCallback onSearch;

  /// Callback para la acción de filtrar.
  final VoidCallback onFilter;

  /// Callback para la acción de limpiar.
  final VoidCallback onClear;

  /// Callback para la acción de generar horarios.
  final VoidCallback onGenerate;

  const MainActionsPanel({
    Key? key,
    required this.onSearch,
    required this.onFilter,
    required this.onClear,
    required this.onGenerate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Botón para buscar materia.
            Expanded(
                child: _MainCardButton(
                    color: const Color(0xFF0051FF),
                    icon: Icons.search,
                    label: "Buscar materia",
                    onTap: onSearch)),
            const SizedBox(width: 20),
            // Botón para realizar filtro.
            Expanded(
                child: _MainCardButton(
                    color: const Color(0xFF0051FF),
                    icon: Icons.filter_alt,
                    label: "Realizar filtro",
                    onTap: onFilter)),
            const SizedBox(width: 20),
            // Botón para limpiar horarios.
            Expanded(
                child: _MainCardButton(
                    color: const Color(0xFFFF2F2F),
                    icon: Icons.delete_outline,
                    label: "Limpiar Horarios",
                    onTap: onClear)),
          ],
        ),
        const SizedBox(height: 28),
        // Botón principal para generar horarios.
        SizedBox(
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8CFF62),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            onPressed: onGenerate,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Generar Horarios",
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                Icon(Icons.calendar_month, color: Colors.black),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// Un botón de tarjeta personalizado con efecto hover para el panel de acciones.
class _MainCardButton extends StatefulWidget {
  /// Color de fondo del botón.
  final Color color;

  /// Ícono que se muestra en el botón.
  final IconData icon;

  /// Etiqueta de texto del botón.
  final String label;

  /// Callback que se ejecuta al tocar el botón.
  final VoidCallback onTap;

  const _MainCardButton(
      {required this.color,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  State<_MainCardButton> createState() => _MainCardButtonState();
}

class _MainCardButtonState extends State<_MainCardButton> {
  /// Controla si el cursor está sobre el botón para el efecto visual.
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color hoverColor = widget.color.withOpacity(0.8);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: _isHovered ? hoverColor : widget.color,
            borderRadius: BorderRadius.circular(16),
            // Sombra que aparece al pasar el cursor sobre el botón.
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4))
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}