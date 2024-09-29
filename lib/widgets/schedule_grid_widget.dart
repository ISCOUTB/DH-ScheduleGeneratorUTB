// lib/widgets/schedule_grid_widget.dart
import 'package:flutter/material.dart';
import '../models/class_option.dart';

class ScheduleGridWidget extends StatelessWidget {
  final List<List<ClassOption>> allSchedules;
  final Function(int) onScheduleTap;

  const ScheduleGridWidget({
    Key? key,
    required this.allSchedules,
    required this.onScheduleTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: allSchedules.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Ajusta el número de columnas según tus necesidades
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => onScheduleTap(index),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.all(8),
            child: buildSchedulePreview(allSchedules[index]),
          ),
        );
      },
    );
  }

  Widget buildSchedulePreview(List<ClassOption> schedule) {
    final List<String> timeSlots = [
      '07:00 AM',
      '08:00 AM',
      '09:00 AM',
      '10:00 AM',
      '11:00 AM',
      '12:00 PM',
      '01:00 PM',
      '02:00 PM',
      '03:00 PM',
      '04:00 PM',
      '05:00 PM',
      '06:00 PM',
      '07:00 PM',
      '08:00 PM',
    ];

    final List<String> days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

    Map<String, Map<String, ClassOption?>> scheduleMatrix = {};

    for (String time in timeSlots) {
      scheduleMatrix[time] = {};
      for (String day in days) {
        scheduleMatrix[time]![day] = null; // Inicialmente vacío
      }
    }

    // Llenar la matriz del horario con las clases
    for (var classOption in schedule) {
      for (var sched in classOption.schedules) {
        TimeOfDayRange range = parseTimeRange(sched.time);
        String day = sched.day;

        int startIndex = timeSlots.indexOf(formatTimeOfDay(range.start));
        int endIndex = timeSlots.indexOf(formatTimeOfDay(range.end));

        if (startIndex == -1 || endIndex == -1) continue;

        for (int i = startIndex; i < endIndex; i++) {
          scheduleMatrix[timeSlots[i]]![day] = classOption;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          // Encabezado de días
          Row(
            children: days
                .map((day) => Expanded(
                      child: Text(
                        day.substring(0, 2),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          // Horarios
          Expanded(
            child: GridView.count(
              crossAxisCount: days.length,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              children: [
                for (var time in timeSlots)
                  for (var day in days)
                    Container(
                      margin: const EdgeInsets.all(1),
                      color: scheduleMatrix[time]![day] != null
                          ? Colors.blueAccent
                          : Colors.grey[200],
                      child: scheduleMatrix[time]![day] != null
                          ? Center(
                              child: Text(
                                scheduleMatrix[time]![day]!.subjectName.substring(0, 3),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          : null,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Funciones auxiliares para parsear y formatear horarios
  TimeOfDayRange parseTimeRange(String timeRange) {
    List<String> parts = timeRange.split(' - ');
    TimeOfDay start = parseTimeOfDay(parts[0]);
    TimeOfDay end = parseTimeOfDay(parts[1]);
    return TimeOfDayRange(start, end);
  }

  TimeOfDay parseTimeOfDay(String timeString) {
    // Eliminar espacios y convertir a mayúsculas
    timeString = timeString.trim().toUpperCase();

    // Extraer AM/PM
    bool isPM = timeString.endsWith('PM');
    timeString = timeString.replaceAll(RegExp(r'AM|PM'), '').trim();

    // Separar horas y minutos
    List<String> timeParts = timeString.split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    // Ajustar para formato de 12 horas
    if (isPM && hour < 12) {
      hour += 12;
    }
    if (!isPM && hour == 12) {
      hour = 0;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:${minute} $period';
  }
}

// Definición de TimeOfDayRange
class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);
}
