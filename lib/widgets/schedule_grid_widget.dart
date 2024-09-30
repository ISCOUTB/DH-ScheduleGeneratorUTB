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
        crossAxisCount: 2, // Dos horarios por fila
        childAspectRatio: 2.5, // Más ancho que alto (ajusta este valor según prefieras)
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
      '07:00',
      '08:00',
      '09:00',
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:00',
      '16:00',
      '17:00',
      '18:00',
      '19:00',
      '20:00',
    ];

    final List<String> days = [
      'Lun',
      'Mar',
      'Mié',
      'Jue',
      'Vie',
      'Sáb',
    ];

    // Crear una matriz para almacenar la información de las clases
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
        String day = sched.day.substring(0, 3); // Abreviar el día

        int startIndex = getTimeSlotIndex(range.start, timeSlots);
        int endIndex = getTimeSlotIndex(range.end, timeSlots);

        if (startIndex == -1 || endIndex == -1) continue;

        for (int i = startIndex; i < endIndex; i++) {
          if (i < timeSlots.length) {
            // Almacenar la opción de clase
            scheduleMatrix[timeSlots[i]]![day] = classOption;
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          // Encabezado de días
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days
                .map((day) => Expanded(
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 8),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 2),
          // Horarios
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: timeSlots.map((time) {
                  return Row(
                    children: days.map((day) {
                      ClassOption? classOption = scheduleMatrix[time]![day];
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(0.5),
                          height: 14.5, // Altura ajustada para minimizar
                          color: classOption != null
                              ? Colors.blueAccent
                              : Colors.grey[200],
                          child: classOption != null
                              ? Center(
                                  child: Text(
                                    classOption.subjectName.length > 3
                                        ? classOption.subjectName.substring(0, 3)
                                        : classOption.subjectName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 6,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
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
    timeString = timeString.trim();

    // Separar horas y minutos
    List<String> timeParts = timeString.split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    return TimeOfDay(hour: hour, minute: minute);
  }

  int getTimeSlotIndex(TimeOfDay time, List<String> timeSlots) {
    int timeMinutes = time.hour * 60 + time.minute;

    for (int i = 0; i < timeSlots.length; i++) {
      TimeOfDay slotTime = parseTimeOfDay(timeSlots[i]);
      int slotMinutes = slotTime.hour * 60 + slotTime.minute;

      if (timeMinutes <= slotMinutes) {
        return i;
      }
    }
    return -1;
  }
}

// Definición de TimeOfDayRange
class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);
}
