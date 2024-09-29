// lib/widgets/schedule_overview_widget.dart
import 'package:flutter/material.dart';
import '../models/class_option.dart';
import 'schedule_detail_widget.dart';

class ScheduleOverviewWidget extends StatefulWidget {
  final List<ClassOption> schedule;
  final VoidCallback onClose;

  const ScheduleOverviewWidget({
    Key? key,
    required this.schedule,
    required this.onClose,
  }) : super(key: key);

  @override
  _ScheduleOverviewWidgetState createState() => _ScheduleOverviewWidgetState();
}

class _ScheduleOverviewWidgetState extends State<ScheduleOverviewWidget> {
  @override
  Widget build(BuildContext context) {
    // Obtener las materias únicas
    final subjects = widget.schedule;

    return Dialog(
      child: Container(
        width: 1000,
        height: 800,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Botón de cierre
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            // Botones de materias con ícono de información
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects.map((classOption) {
                return ElevatedButton.icon(
                  onPressed: () {
                    // Mostrar información de la materia
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text(classOption.subjectName),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Profesor: ${classOption.professor}'),
                              Text('Horario completo: ${classOption.schedules.map((s) => s.day + ' ' + s.time).join(', ')}'),
                              Text('Número de créditos: ${classOption.credits}'),
                              // Agrega más información si es necesario
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('Cerrar'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: Icon(Icons.info),
                  label: Text(classOption.subjectName),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            // Widget del horario
            Expanded(
              child: ScheduleDetailWidget(
                schedule: widget.schedule,
                onClose: widget.onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
