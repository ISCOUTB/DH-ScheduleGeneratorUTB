import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/custom_course.dart';
import '../models/subject.dart';
import '../utils/credit_utils.dart';

/// Un panel que muestra las materias seleccionadas y el conteo de créditos.
///
/// Se adapta para mostrarse como un panel lateral en escritorio o como una
/// tarjeta en la vista móvil.
class SubjectsPanel extends StatelessWidget {
  /// Controla si el panel está en su vista mínima (colapsada).
  final bool isFullExpandedView;

  /// La lista de materias que el usuario ha agregado.
  final List<Subject> addedSubjects;

  /// El número de créditos actualmente en uso (decimal: hay materias de 0.5).
  final double usedCredits;

  /// El límite de créditos permitido.
  final double creditLimit;

  /// Mapa de colores para las materias.
  final Map<String, Color> subjectColors;

  /// Callback para mostrar el panel en su vista expandida.
  final VoidCallback onShowPanel;

  /// Callback para ocultar el panel a su vista colapsada.
  final VoidCallback onHidePanel;

  /// Callback para iniciar el proceso de agregar una nueva materia.
  final VoidCallback onAddSubject;

  /// Callback para abrir el panel de gestión de cursos personalizados.
  final VoidCallback onOpenCustomCourses;

  /// Cantidad de cursos personalizados del usuario (para el aviso del header).
  final int customCoursesCount;

  /// Cursos personalizados por materia (`subjectKey`), para el anidado + switch.
  final Map<String, List<CustomCourse>> customCoursesByKey;

  /// Enciende/apaga un curso personalizado desde el anidado.
  final void Function(int id, bool activo) onToggleCustomCourse;

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
    required this.subjectColors,
    required this.onShowPanel,
    required this.onHidePanel,
    required this.onAddSubject,
    required this.onOpenCustomCourses,
    this.customCoursesCount = 0,
    this.customCoursesByKey = const {},
    required this.onToggleCustomCourse,
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
          Row(
            children: [
              const Text("2026-2P",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
              const Spacer(),
              _headerCustomAviso(),
            ],
          ),
          const SizedBox(height: 4),
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
            Column(children: addedSubjects.map(_subjectCard).toList()),
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

  /// Aviso clickeable con el conteo de cursos personalizados, para el header
  /// (extremo opuesto al término). Vacío si no hay ninguno.
  Widget _headerCustomAviso() {
    if (customCoursesCount <= 0) return const SizedBox.shrink();
    return InkWell(
      onTap: onOpenCustomCourses,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_note, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              customCoursesCount == 1 ? '1 personalizado' : '$customCoursesCount personalizados',
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de una materia con sus cursos personalizados anidados (colapsables).
  Widget _subjectCard(Subject subject) => _SubjectCard(
        subject: subject,
        color: subjectColors[subject.key] ?? Colors.grey,
        customs: customCoursesByKey[subject.key] ?? const <CustomCourse>[],
        onRemove: () => onRemoveSubject(subject),
        onToggleCustom: onToggleCustomCourse,
      );

  /// Construye la vista expandida del panel de escritorio.
  Widget _buildExpandedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("2026-2P",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
            const Spacer(),
            _headerCustomAviso(),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Materias Seleccionadas",
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
                ...addedSubjects.map(_subjectCard),
                const SizedBox(height: 12),
                // Ambos botones contiguos, centrados como grupo (una sola fila).
                // FittedBox(scaleDown): muestra el texto completo y, solo si no
                // cupiera, escala el grupo en vez de cortar la palabra.
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onAddSubject,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Agregar materia"),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: onOpenCustomCourses,
                          icon: const Icon(Icons.event_note, size: 18),
                          label: const Text("Crear curso"),
                        ),
                      ],
                    ),
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
            text: "${formatCredits(usedCredits)}/${formatCredits(creditLimit)}",
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

/// Tarjeta de una materia con sus cursos personalizados anidados debajo. Los
/// cursos se pueden **expandir/contraer** con un chevron (solo si los hay).
class _SubjectCard extends StatefulWidget {
  final Subject subject;
  final Color color;
  final List<CustomCourse> customs;
  final VoidCallback onRemove;
  final void Function(int id, bool activo) onToggleCustom;

  const _SubjectCard({
    required this.subject,
    required this.color,
    required this.customs,
    required this.onRemove,
    required this.onToggleCustom,
  });

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final hasCustoms = widget.customs.isNotEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
            title: Text(widget.subject.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasCustoms)
                  IconButton(
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                    tooltip: _expanded
                        ? 'Ocultar cursos personalizados'
                        : 'Ver cursos personalizados',
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  tooltip: 'Quitar materia',
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ),
          if (hasCustoms && _expanded) ...[
            ...widget.customs.map(_customTile),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _customTile(CustomCourse c) {
    final bloques =
        c.bloques.map((b) => '${b.day.substring(0, 3)} ${b.time}').join(' · ');
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 8, bottom: 6),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFD1D5DB), width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_note, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.etiqueta?.trim().isNotEmpty == true
                              ? c.etiqueta!
                              : 'Curso personalizado',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800),
                        ),
                      ),
                    ],
                  ),
                  Text(bloques, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: c.activo,
                activeColor: AppColors.primary,
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade300,
                onChanged: (v) => widget.onToggleCustom(c.id, v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
