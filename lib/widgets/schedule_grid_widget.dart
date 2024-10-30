// lib/widgets/schedule_grid_widget.dart
import 'package:flutter/material.dart';
import '../models/class_option.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb y defaultTargetPlatform

class ScheduleGridWidget extends StatelessWidget {
  final List<List<ClassOption>> allSchedules;
  final Function(int) onScheduleTap;

  const ScheduleGridWidget({
    Key? key,
    required this.allSchedules,
    required this.onScheduleTap,
  }) : super(key: key);

  bool isMobile() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    bool mobile = isMobile();
    int crossAxisCount = mobile ? 1 : 2;

    // Generar el mapa de colores para las materias
    Map<String, Color> subjectColors = _generateSubjectColors();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ajustar el aspect ratio en móvil
        double childAspectRatio = mobile ? 2.5 : 1.5; // Mayor ratio en móvil

        return GridView.builder(
          itemCount: allSchedules.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => onScheduleTap(index),
              child: Card(
                elevation: 2,
                margin: const EdgeInsets.all(8),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10), // Esquinas redondeadas
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(10), // Esquinas redondeadas
                    border: Border.all(
                      color: Colors.white, // Color del borde
                      width: 2, // Ancho del borde
                    ),
                  ),
                  child:
                      buildSchedulePreview(allSchedules[index], subjectColors),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildSchedulePreview(
      List<ClassOption> schedule, Map<String, Color> subjectColors) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cálculo de tamaños adaptativos
        double totalWidth = constraints.maxWidth;
        double totalHeight = constraints.maxHeight;

        double hourColumnWidth = totalWidth * 0.10; // 10% del ancho total
        double dayColumnWidth = (totalWidth - hourColumnWidth) / days.length;

        double cellHeight =
            totalHeight / (timeSlots.length + 1); // +1 para el encabezado

        double fontSize = cellHeight * 0.5; // Ajusta según sea necesario

        return Column(
          children: [
            // Encabezado de días
            Row(
              children: [
                SizedBox(
                  width: hourColumnWidth,
                  child: const Text(''),
                ),
                ...days.map((day) => SizedBox(
                      width: dayColumnWidth,
                      child: Center(
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: fontSize * 0.8,
                          ),
                        ),
                      ),
                    )),
              ],
            ),
            // Horarios
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: timeSlots.length,
                itemBuilder: (context, rowIndex) {
                  String time = timeSlots[rowIndex];
                  return Row(
                    children: [
                      // Columna de horas
                      SizedBox(
                        width: hourColumnWidth,
                        height: cellHeight,
                        child: Center(
                          child: Text(
                            time,
                            style: TextStyle(
                              fontSize: fontSize * 0.7,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      ...days.map((day) {
                        ClassOption? classOption = scheduleMatrix[time]![day];
                        Color? subjectColor;
                        if (classOption != null) {
                          subjectColor =
                              subjectColors[classOption.subjectName] ??
                                  Colors.blueAccent;
                        }
                        return SizedBox(
                          width: dayColumnWidth,
                          height: cellHeight,
                          child: Container(
                            margin: const EdgeInsets.all(0.5),
                            decoration: BoxDecoration(
                              color: classOption != null
                                  ? subjectColor
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: classOption != null
                                ? Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        classOption.subjectName.length > 3
                                            ? classOption.subjectName
                                                .split(' ')
                                                .first
                                            : classOption.subjectName,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: fontSize * 0.6,
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Generar un mapa de colores para las materias
  Map<String, Color> _generateSubjectColors() {
    List<Color> colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.cyanAccent,
      Colors.amberAccent,
      Colors.tealAccent,
      Colors.indigoAccent,
      Colors.pinkAccent,
      Colors.limeAccent,
      Colors.deepOrangeAccent,
      Colors.lightBlueAccent,
      Colors.lightGreenAccent,
      Colors.deepPurpleAccent,
    ];

    Map<String, Color> subjectColors = {};
    int colorIndex = 0;

    // Suponiendo que tenemos acceso a todas las materias
    Set<String> allSubjects = {};
    for (var schedule in allSchedules) {
      for (var classOption in schedule) {
        allSubjects.add(classOption.subjectName);
      }
    }

    for (var subject in allSubjects) {
      subjectColors[subject] = colors[colorIndex % colors.length];
      colorIndex++;
    }

    return subjectColors;
  }

  // Funciones auxiliares para parsear y formatear horarios
  TimeOfDayRange parseTimeRange(String timeRange) {
    List<String> parts = timeRange.split(' - ');
    TimeOfDay start = parseTimeOfDay(parts[0]);
    TimeOfDay end = parseTimeOfDay(parts[1]);
    return TimeOfDayRange(start, end);
  }

  TimeOfDay parseTimeOfDay(String timeString) {
    timeString = timeString.trim();

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
