import 'package:flutter/material.dart';
import '../models/subject.dart';

/// Un panel que muestra las materias seleccionadas y el conteo de créditos.
///
/// Se adapta para mostrarse como un panel lateral en escritorio o como una
/// tarjeta en la vista móvil.
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

  /// Determina si se debe usar el layout para móvil.
  final bool isMobileLayout;

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
    this.isMobileLayout = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Elige el layout basado en el flag.
    if (isMobileLayout) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  /// Construye el layout de escritorio (panel lateral colapsable).
  Widget _buildDesktopLayout() {
    return Container(
      width: isFullExpandedView ? 60 : 340,
      decoration: _buildPanelDecoration(),
      padding: isFullExpandedView
          ? const EdgeInsets.only(top: 12)
          : const EdgeInsets.all(20),
      child: isFullExpandedView ? _buildCollapsedView() : _buildExpandedView(),
    );
  }

  /// Construye el layout móvil (una tarjeta dentro de la lista principal).
  Widget _buildMobileLayout() {
    return Container(
      decoration: _buildPanelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Materias seleccionadas",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 4),
          // Lista de materias o mensaje si está vacía.
          if (addedSubjects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  "Usa el botón (+) para agregar materias.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Column(
              children: addedSubjects.asMap().entries.map((entry) {
                final idx = entry.key;
                final subject = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
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
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      onPressed: () => onRemoveSubject(subject),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          // Contador de créditos alineado a la derecha.
          Align(
            alignment: Alignment.centerRight,
            child: _buildCreditCounter(),
          ),
        ],
      ),
    );
  }

  /// Construye la vista colapsada del panel de escritorio.
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

  /// Construye la vista expandida del panel de escritorio.
  Widget _buildExpandedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Materias",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            IconButton(
              tooltip: "Encoger panel",
              icon: const Icon(Icons.chevron_right,
                  size: 32, color: Colors.black54),
              onPressed: onHidePanel,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                ...addedSubjects.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final subject = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
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
                      trailing: IconButton(
                        icon: const Icon(Icons.remove, color: Colors.red),
                        onPressed: () => onRemoveSubject(subject),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: onToggleExpandView,
              icon: Icon(
                  isExpandedView ? Icons.fullscreen_exit : Icons.fullscreen),
              label: Text(isExpandedView ? "Vista Normal" : "Expandir Vista"),
            ),
            _buildCreditCounter(),
          ],
        ),
      ],
    );
  }

  /// Construye la decoración base para el panel/tarjeta.
  BoxDecoration _buildPanelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
      ],
    );
  }

  /// Construye el widget de texto para el contador de créditos.
  Widget _buildCreditCounter() {
    return Text.rich(
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
    );
  }
}
