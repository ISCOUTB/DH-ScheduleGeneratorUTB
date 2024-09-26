// lib/widgets/schedule_preview_widget.dart
import 'package:flutter/material.dart';

class SchedulePreviewWidget extends StatelessWidget {
  final List<Map<String, List<String>>> schedule;

  const SchedulePreviewWidget({
    Key? key,
    required this.schedule,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Definir las horas de inicio y fin del horario
    final List<String> timeSlots = [
      '08:00 - 09:00',
      '09:00 - 10:00',
      '10:00 - 11:00',
      '11:00 - 12:00',
      '12:00 - 13:00',
      '13:00 - 14:00',
      '14:00 - 15:00',
      '15:00 - 16:00',
      '16:00 - 17:00',
      '17:00 - 18:00',
      '18:00 - 19:00',
      '19:00 - 20:00',
    ];

    // Ordenar días en orden específico
    final List<String> days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado'
    ];

    // Crear una matriz para representar el horario completo
    Map<String, Map<String, String>> scheduleMatrix = {};

    for (String time in timeSlots) {
      scheduleMatrix[time] = {};
      for (String day in days) {
        scheduleMatrix[time]![day] = ''; // Inicialmente vacío
      }
    }

    // Rellenar la matriz con las materias
    for (var daySchedule in schedule) {
      String day = daySchedule.keys.first;
      List<String> subjects = daySchedule.values.first;

      for (String subjectInfo in subjects) {
        // Asumimos que el formato es "Materia (hora)"
        if (subjectInfo.contains('(') && subjectInfo.contains(')')) {
          String subjectName =
              subjectInfo.substring(0, subjectInfo.indexOf('(')).trim();
          String time = subjectInfo.substring(
              subjectInfo.indexOf('(') + 1, subjectInfo.indexOf(')'));

          // Limpiar espacios en blanco
          time = time.trim();

          // Ubicar la materia en la matriz
          if (scheduleMatrix.containsKey(time)) {
            scheduleMatrix[time]![day] = subjectName;
          }
        }
      }
    }

    // Construir la tabla
    return Column(
      children: [
        const Text(
          'Horario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: 120, // Establece una altura fija adecuada
          child: SingleChildScrollView(
            child: Table(
              border: TableBorder.all(color: Colors.grey),
              defaultColumnWidth: const IntrinsicColumnWidth(),
              children: [
                // Fila de encabezados (días)
                TableRow(
                  children: [
                    Container(), // Celda vacía en la esquina superior izquierda
                    ...days.map((day) => Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            day.substring(0, 3), // Abreviatura del día
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        )),
                  ],
                ),
                // Filas de horas
                ...timeSlots.map((time) {
                  return TableRow(
                    children: [
                      // Columna de horas
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          time,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                      // Celdas de materias
                      ...days.map((day) {
                        String subjectName = scheduleMatrix[time]![day] ?? '';
                        return Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            subjectName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 8),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
