// lib/widgets/layout/speed_dial_menu.dart
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../config/constants.dart';

/// Menú de acciones rápidas (SpeedDial) para la vista móvil.
class SpeedDialMenu extends StatelessWidget {
  /// Callback para buscar materia.
  final VoidCallback onSearch;

  /// Callback para abrir filtros.
  final VoidCallback onFilter;

  /// Callback para mostrar información de creadores.
  final VoidCallback onShowCreators;

  /// Callback para abrir Preguntas frecuentes.
  final VoidCallback onQuestions;

  /// Callback para limpiar todo.
  final VoidCallback onClear;

  /// Callback para abrir horarios destacados.
  final VoidCallback? onFavorites;

  /// Callback para abrir el panel de cursos personalizados (crear curso).
  final VoidCallback? onCustomCourses;

  const SpeedDialMenu({
    Key? key,
    required this.onSearch,
    required this.onFilter,
    required this.onShowCreators,
    required this.onQuestions,
    required this.onClear,
    this.onFavorites,
    this.onCustomCourses,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.search),
          label: 'Buscar Materia',
          onTap: onSearch,
        ),
        SpeedDialChild(
          child: const Icon(Icons.filter_alt),
          label: 'Realizar Filtro',
          onTap: onFilter,
        ),
        if (onFavorites != null)
          SpeedDialChild(
            child: const Icon(Icons.star, color: Colors.amber),
            label: 'Mis Horarios',
            onTap: onFavorites,
          ),
        if (onCustomCourses != null)
          SpeedDialChild(
            child: const Icon(Icons.event_note),
            label: 'Crear curso',
            onTap: onCustomCourses,
          ),
        SpeedDialChild(
          child: const Icon(Icons.help_outline),
          label: 'Preguntas frecuentes',
          onTap: onQuestions,
        ),
        SpeedDialChild(
          child: const Icon(Icons.info_outline),
          label: 'Creadores',
          onTap: onShowCreators,
        ),
        // Limpiar Todo, último.
        SpeedDialChild(
          child: const Icon(Icons.delete_forever, color: Colors.white),
          label: 'Limpiar Todo',
          backgroundColor: AppColors.dark,
          onTap: onClear,
        ),
      ],
    );
  }
}
