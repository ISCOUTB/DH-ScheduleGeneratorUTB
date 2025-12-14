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

  /// Callback para abrir tutorial.
  final VoidCallback onTutorial;

  /// Callback para mostrar información de creadores.
  final VoidCallback onShowCreators;

  /// Callback para limpiar todo.
  final VoidCallback onClear;

  const SpeedDialMenu({
    Key? key,
    required this.onSearch,
    required this.onFilter,
    required this.onTutorial,
    required this.onShowCreators,
    required this.onClear,
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
        SpeedDialChild(
          child: const Icon(Icons.school),
          label: 'Tutorial',
          onTap: onTutorial,
        ),
        SpeedDialChild(
          child: const Icon(Icons.info_outline),
          label: 'Creadores',
          onTap: onShowCreators,
        ),
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
