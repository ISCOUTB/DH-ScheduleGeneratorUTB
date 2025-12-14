// lib/widgets/dialogs/creators_dialog.dart
import 'package:flutter/material.dart';
import '../../config/constants.dart';

/// Diálogo que muestra información sobre los creadores de la aplicación.
class CreatorsDialog extends StatelessWidget {
  const CreatorsDialog({Key? key}) : super(key: key);

  /// Muestra el diálogo de creadores.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const CreatorsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Acerca de', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La idea y los primeros avances de esta aplicación surgieron en la asignatura Desarrollo de Software de la Universidad Tecnológica de Bolívar, bajo la instrucción del profesor Jairo Enrique Serrano Castañeda.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'Equipo del prototipo inicial:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              ..._buildTeamList(_initialTeam),
              const SizedBox(height: 12),
              const Text(
                'Equipo de desarrollo actual:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              ..._buildTeamList(_currentTeam),
              const SizedBox(height: 12),
              const Text(
                'Todos los estudiantes mencionados pertenecen a la Escuela de Transformación Digital, del programa de Ingeniería en Sistemas y Computación de la Universidad Tecnológica de Bolívar (UTB).',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  List<Widget> _buildTeamList(List<String> members) {
    return members
        .map((name) => Text(' • $name', style: const TextStyle(fontSize: 13)))
        .toList();
  }

  static const List<String> _initialTeam = [
    'Gabriel Alejandro Mantilla Clavijo',
    'Melany Marcela Saez Acuña',
    'Eddy Josue Lara Cermeno',
    'Julio de Jesús Denubila Vergara',
    'Diego Peña Páez',
  ];

  static const List<String> _currentTeam = [
    'Gabriel Alejandro Mantilla Clavijo',
    'Melany Marcela Saez Acuña',
  ];
}
