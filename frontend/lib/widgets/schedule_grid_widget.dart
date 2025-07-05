// lib/widgets/schedule_grid_widget.dart
import 'package:flutter/material.dart';
import '../models/class_option.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb y defaultTargetPlatform

/// Muestra una cuadrícula de previsiones de horarios generados.
///
/// Cada celda de la cuadrícula representa un horario y es interactiva.
/// El diseño es adaptable para web, escritorio y dispositivos móviles.
/// Implementa paginación para manejar de forma eficiente un gran número de horarios.
class ScheduleGridWidget extends StatefulWidget {
  /// La lista de todos los horarios generados, donde cada horario es una lista de clases.
  final List<List<ClassOption>> allSchedules;

  /// Callback que se ejecuta cuando se toca un horario, devolviendo su índice.
  final Function(int) onScheduleTap;

  const ScheduleGridWidget({
    Key? key,
    required this.allSchedules,
    required this.onScheduleTap,
  }) : super(key: key);

  @override
  State<ScheduleGridWidget> createState() => _ScheduleGridWidgetState();
}

class _ScheduleGridWidgetState extends State<ScheduleGridWidget> {
  final ScrollController _scrollController = ScrollController();
  List<List<ClassOption>> _displayedSchedules = [];
  bool _isLoading = false;
  final int _itemsPerPage = 10; // Número de horarios a cargar cada vez

  @override
  void initState() {
    super.initState();
    _loadInitialSchedules();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ScheduleGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la lista de horarios cambia (ej. nueva generación), reinicia la vista.
    if (widget.allSchedules != oldWidget.allSchedules) {
      _loadInitialSchedules();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadInitialSchedules() {
    setState(() {
      _displayedSchedules = widget.allSchedules.take(_itemsPerPage).toList();
    });
  }

  void _onScroll() {
    // Si el usuario está cerca del final de la lista y no estamos cargando, carga más.
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading) {
      _loadMoreSchedules();
    }
  }

  void _loadMoreSchedules() {
    // No hacer nada si ya estamos cargando o si ya se han mostrado todos los horarios.
    if (_isLoading || _displayedSchedules.length >= widget.allSchedules.length) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simula una pequeña demora para que el indicador de carga sea visible.
    Future.delayed(const Duration(milliseconds: 500), () {
      final int currentLength = _displayedSchedules.length;
      final List<List<ClassOption>> nextBatch = widget.allSchedules
          .skip(currentLength)
          .take(_itemsPerPage)
          .toList();

      setState(() {
        _displayedSchedules.addAll(nextBatch);
        _isLoading = false;
      });
    });
  }

  /// Comprueba si la plataforma actual es móvil (Android o iOS).
  bool isMobile() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    bool mobile = isMobile();
    int crossAxisCount = mobile ? 1 : 2;

    // Genera un mapa de colores único para cada materia.
    Map<String, Color> subjectColors = _generateSubjectColors();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ajusta la relación de aspecto para una mejor visualización en móviles.
        double childAspectRatio = mobile ? 2.5 : 1.5; // Mayor ratio en móvil

        return GridView.builder(
          controller: _scrollController,
          itemCount: _displayedSchedules.length + (_isLoading ? 1 : 0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            // Si es el último item y estamos cargando, muestra un indicador de progreso.
            if (index == _displayedSchedules.length) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            //MouseRegion
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => widget.onScheduleTap(index),
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
                    // Construye la vista previa visual del horario.
                    child: buildSchedulePreview(
                        _displayedSchedules[index], subjectColors),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Construye la vista previa visual de un único horario en formato de cuadrícula.
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
      'Dom',
    ];

    // Matriz para almacenar las clases organizadas por día y hora.
    Map<String, Map<String, ClassOption?>> scheduleMatrix = {};

    for (String time in timeSlots) {
      scheduleMatrix[time] = {};
      for (String day in days) {
        scheduleMatrix[time]![day] = null; // Inicialmente vacío
      }
    }

    // Llena la matriz con las clases del horario.
    for (var classOption in schedule) {
      for (var sched in classOption.schedules) {
        TimeOfDayRange range = parseTimeRange(sched.time);
        String day = sched.day.substring(0, 3); // Abreviar el día

        int startIndex = getTimeSlotIndex(range.start, timeSlots);
        int endIndex = getTimeSlotIndex(range.end, timeSlots);

        if (startIndex == -1 || endIndex == -1) continue;

        for (int i = startIndex; i < endIndex; i++) {
          if (i < timeSlots.length) {
            // Almacena la opción de clase en la celda correspondiente.
            scheduleMatrix[timeSlots[i]]![day] = classOption;
          }
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula tamaños de celda y fuente adaptativos basados en el espacio disponible.
        double totalWidth = constraints.maxWidth;
        double totalHeight = constraints.maxHeight;

        double hourColumnWidth = totalWidth * 0.10; // 10% del ancho total
        double dayColumnWidth = (totalWidth - hourColumnWidth) / days.length;

        double cellHeight =
            totalHeight / (timeSlots.length + 1); // +1 para el encabezado

        double fontSize = cellHeight * 0.5; // Ajusta según sea necesario

        return Column(
          children: [
            // Fila de encabezado con los nombres de los días.
            SizedBox(
              height: cellHeight,
              child: Row(
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
            ),
            // Cuerpo de la cuadrícula con las horas y las clases.
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: timeSlots.map((time) {
                  return Row(
                    children: [
                      // Columna de horas.
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
                      // Celdas para cada día de la semana.
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
                            // Muestra el nombre abreviado de la materia.
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
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Genera un mapa de colores único para cada materia en los horarios.
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

    // Extrae todos los nombres de materias únicos.
    Set<String> allSubjects = {};
    for (var schedule in widget.allSchedules) {
      for (var classOption in schedule) {
        allSubjects.add(classOption.subjectName);
      }
    }

    // Asigna un color a cada materia.
    for (var subject in allSubjects) {
      subjectColors[subject] = colors[colorIndex % colors.length];
      colorIndex++;
    }

    return subjectColors;
  }

  /// Parsea una cadena de rango de tiempo (ej. "07:00 - 09:00") a un objeto TimeOfDayRange.
  TimeOfDayRange parseTimeRange(String timeRange) {
    List<String> parts = timeRange.split(' - ');
    TimeOfDay start = parseTimeOfDay(parts[0]);
    TimeOfDay end = parseTimeOfDay(parts[1]);
    return TimeOfDayRange(start, end);
  }

  /// Parsea una cadena de tiempo (ej. "07:00") a un objeto TimeOfDay.
  TimeOfDay parseTimeOfDay(String timeString) {
    timeString = timeString.trim();

    List<String> timeParts = timeString.split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Encuentra el índice de una franja horaria correspondiente a una hora específica.
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

/// Representa un rango de tiempo con una hora de inicio y una de fin.
class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);
}