import 'package:flutter/material.dart';
import '../models/subject.dart';

/// Un panel lateral que muestra las materias seleccionadas y el conteo de créditos.
///
/// Ofrece dos vistas: una colapsada que solo muestra un botón para expandir,
/// y una expandida que lista las materias y las acciones disponibles.
class SubjectsPanel extends StatelessWidget {
  /// Controla si el panel está en su vista mínima (colapsada).
  final bool isFullExpandedView;

  /// La lista de materias que el usuario ha agregado.
  final List<Subject> addedSubjects;

  /// El número de créditos actualmente en uso.
  final int usedCredits;

  /// El límite de créditos permitido.
  final int creditLimit;

  /// Función que devuelve un color para una materia específica, basado en su índice.
  final Color Function(int) getSubjectColor;

  /// Callback para mostrar el panel en su vista expandida.
  final VoidCallback onShowPanel;

  /// Callback para ocultar el panel a su vista colapsada.
  final VoidCallback onHidePanel;

  /// Callback para iniciar el proceso de agregar una nueva materia.
  final VoidCallback onAddSubject;

  /// Callback para alternar la vista de la cuadrícula de horarios.
  final VoidCallback onToggleExpandView;

  /// Callback para eliminar una materia de la lista.
  final Function(Subject) onRemoveSubject;

  /// Indica si la vista de la cuadrícula de horarios está expandida.
  final bool isExpandedView;

  const SubjectsPanel({
    Key? key,
    required this.isFullExpandedView,
    required this.addedSubjects,
    required this.usedCredits,
    required this.creditLimit,
    required this.getSubjectColor,
    required this.onShowPanel,
    required this.onHidePanel,
    required this.onAddSubject,
    required this.onToggleExpandView,
    required this.onRemoveSubject,
    required this.isExpandedView,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // El ancho cambia dependiendo de si la vista está colapsada o expandida.
      width: isFullExpandedView ? 60 : 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      padding: isFullExpandedView
          ? const EdgeInsets.only(top: 12)
          : const EdgeInsets.all(20),
      // Muestra la vista colapsada o expandida según el estado.
      child: isFullExpandedView
          ? _buildCollapsedView()
          : _buildExpandedView(),
    );
  }

  /// Construye la vista colapsada del panel, que solo muestra un botón para expandir.
  Widget _buildCollapsedView() {
    return Column(
      children: [
        const SizedBox(height: 4),
        Center(
          child: Tooltip(
            message: "Mostrar panel",
            child: IconButton(
              icon: const Icon(Icons.chevron_left,
                  size: 32, color: Colors.black54),
              onPressed: onShowPanel,
            ),
          ),
        ),
      ],
    );
  }

  /// Construye la vista expandida del panel con la lista de materias y acciones.
  Widget _buildExpandedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado con título y botón para colapsar.
        Row(
          children: [
            const Text("Materias seleccionadas",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            const SizedBox(width: 8),
            IconButton(
              tooltip: "Encoger panel",
              icon: const Icon(Icons.chevron_right,
                  size: 32, color: Colors.black54),
              onPressed: onHidePanel,
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Lista de materias agregadas.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Mapea cada materia a un widget de tarjeta (Card).
                ...addedSubjects.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final subject = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      // Indicador de color para la materia.
                      leading: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: getSubjectColor(idx),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(subject.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      // Botón para eliminar la materia.
                      trailing: IconButton(
                        icon: const Icon(Icons.remove, color: Colors.red),
                        onPressed: () => onRemoveSubject(subject),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                // Botón para agregar una nueva materia.
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onAddSubject,
                    icon: const Icon(Icons.add),
                    label: const Text("Agregar materia"),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Pie de página con el botón de expandir vista y el contador de créditos.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botón para alternar la vista de la cuadrícula de horarios.
            OutlinedButton.icon(
              onPressed: onToggleExpandView,
              icon: Icon(
                  isExpandedView ? Icons.fullscreen_exit : Icons.fullscreen),
              label: Text(isExpandedView ? "Vista Normal" : "Expandir Vista"),
            ),
            // Contador de créditos.
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: "Créditos: ",
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                  TextSpan(
                    text: "$usedCredits/$creditLimit",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2979FF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}