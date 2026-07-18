// lib/widgets/custom_course/custom_courses_panel.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../models/custom_course.dart';
import '../../providers/schedule_provider.dart';
import '../common/common.dart';
import 'custom_course_wizard.dart';

/// Panel de gestión (biblioteca) de cursos personalizados: todos los del
/// usuario, agrupados por materia, se seleccione o no la materia. Aquí se crean,
/// editan, borran y se prende/apaga el switch de cada uno.
class CustomCoursesPanel extends StatelessWidget {
  const CustomCoursesPanel({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const CustomCoursesPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Consumer<ScheduleProvider>(
            builder: (context, provider, _) {
              final courses = provider.customCourses;
              // Agrupa por materia (subjectKey), conservando orden.
              final Map<String, List<CustomCourse>> byKey = {};
              for (final c in courses) {
                byKey.putIfAbsent(c.subjectKey, () => []).add(c);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_note, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Cursos personalizados',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => CustomCourseWizard.show(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Agregar curso'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _infoBanner(),
                  const Divider(height: 20),
                  Expanded(
                    child: byKey.isEmpty
                        ? _emptyState()
                        : ListView(
                            children: byKey.entries
                                .map((e) => _materiaGroup(context, provider, e.key, e.value))
                                .toList(),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Aviso azul que explica para qué sirve el panel (como el de "Buscar Materia").
  Widget _infoBanner() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Un curso personalizado fija un curso que ya tienes o decidiste '
                '(aunque no esté en la oferta). Marca sus horas y el generador '
                'arma el resto del horario a su alrededor.',
                style: TextStyle(color: Colors.blue.shade700, fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ),
      );

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No tienes cursos personalizados',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Text(
              'Crea uno para fijar un curso que ya tienes\n(o uno que ya no está en la oferta).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );

  Widget _materiaGroup(
      BuildContext context, ScheduleProvider provider, String key, List<CustomCourse> cursos) {
    final first = cursos.first;
    final bool inList = provider.isSubjectInList(key);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de la materia
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(first.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(first.code,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Aviso: la materia no está en la lista de trabajo (RFC §6.4)
          if (!inList)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF9A3412)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Esta materia no está en tu lista; agrégala para generar con este curso.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final err = await provider.addSubjectFromCustom(first);
                      if (err != null && context.mounted) {
                        showCustomNotification(context, err,
                            icon: Icons.info, color: Colors.orange);
                      }
                    },
                    child: const Text('Agregar a mi lista'),
                  ),
                ],
              ),
            ),
          ...cursos.map((c) => _courseRow(context, provider, c, inList)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _courseRow(
      BuildContext context, ScheduleProvider provider, CustomCourse c, bool inList) {
    final bloques = c.bloques
        .map((b) => '${b.day.substring(0, 3)} ${b.time}')
        .join(' · ');
    final titulo = c.etiqueta?.trim().isNotEmpty == true
        ? c.etiqueta!
        : 'Curso personalizado';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          bloques,
          'NRC: ${c.nrc}',
          if (c.professor != null && c.professor!.isNotEmpty) c.professor!,
          '${c.credits.toStringAsFixed(c.credits.truncateToDouble() == c.credits ? 0 : 1)} cr.',
        ].join('  ·  '),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Switch: usa el mío / usa los ofertados. Solo tiene efecto si la
          // materia está en la lista; igual se deja togglear para dejarlo listo.
          Tooltip(
            message: c.activo ? 'Activo (se usa al generar)' : 'Inactivo',
            child: Switch(
              value: c.activo,
              activeColor: AppColors.primary,
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade300,
              onChanged: (v) => provider.toggleCustomCourse(c.id, v),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Editar',
            onPressed: () => CustomCourseWizard.show(context, existing: c),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: 'Eliminar',
            onPressed: () => _confirmDelete(context, provider, c),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ScheduleProvider provider, CustomCourse c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Eliminar curso personalizado'),
        content: Text('¿Eliminar este curso de ${c.name}? No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              provider.deleteCustomCourse(c.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
