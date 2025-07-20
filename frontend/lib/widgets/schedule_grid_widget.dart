// lib/widgets/schedule_grid_widget.dart
import 'package:flutter/material.dart';
import '../models/class_option.dart';

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

  /// Determina si se debe usar el layout para móvil.
  final bool isMobileLayout;

  /// Determina si el GridView debe ser scrollable. Se usa para anidar en otros scrollables.
  final bool isScrollable;

  /// Controlador de scroll opcional, para manejar la paginación desde un scrollable padre.
  final ScrollController? scrollController;

  const ScheduleGridWidget({
    Key? key,
    required this.allSchedules,
    required this.onScheduleTap,
    this.isMobileLayout = false,
    this.isScrollable = true, // Por defecto es scrollable

    this.scrollController,
  }) : super(key: key);

  @override
  State<ScheduleGridWidget> createState() => _ScheduleGridWidgetState();
}

class _ScheduleGridWidgetState extends State<ScheduleGridWidget> {
  // Usa el controlador pasado o crea uno nuevo.
  late final ScrollController _scrollController;
  bool _isInternalController = false;

  List<List<ClassOption>> _displayedSchedules = [];
  bool _isLoading = false;
  final int _itemsPerPage = 10; // Número de horarios a cargar cada vez

  @override
  void initState() {
    super.initState();

    // Determina qué controlador usar.
    if (widget.scrollController == null) {
      _scrollController = ScrollController();
      _isInternalController = true;
    } else {
      _scrollController = widget.scrollController!;
    }

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
    // Solo elimina el controlador si fue creado internamente.
    _scrollController.removeListener(_onScroll);
    if (_isInternalController) {
      _scrollController.dispose();
    }
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
    if (_isLoading ||
        _displayedSchedules.length >= widget.allSchedules.length) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simula una pequeña demora para que el indicador de carga sea visible.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final int currentLength = _displayedSchedules.length;
      final List<List<ClassOption>> nextBatch =
          widget.allSchedules.skip(currentLength).take(_itemsPerPage).toList();

      setState(() {
        _displayedSchedules.addAll(nextBatch);
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    int crossAxisCount = widget.isMobileLayout ? 1 : 2;
    // Ajusta la relación de aspecto para una mejor visualización en móviles.
    double childAspectRatio = widget.isMobileLayout ? 1.8 : 1.5;

    // Genera un mapa de colores único para cada materia.
    Map<String, Color> subjectColors = _generateSubjectColors();

    return GridView.builder(
      physics: widget.isScrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      shrinkWrap: !widget.isScrollable,
      // Asigna el controlador SOLO si el widget es el que se desplaza.
      // Si isScrollable es false, el controlador ya está siendo usado por el
      // ListView padre y adjuntarlo aquí causa el error. La paginación
      // funciona igual porque el listener ya está activo.
      controller: widget.isScrollable ? _scrollController : null,
      padding: const EdgeInsets.all(8),
      itemCount: _displayedSchedules.length +
          (_isLoading && widget.isScrollable ? 1 : 0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        // Si es el último item y estamos cargando, muestra un indicador de progreso.
        if (index == _displayedSchedules.length) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => widget.onScheduleTap(index),
            child: Card(
              elevation: 3,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              // Construye la vista previa visual del horario.
              child: buildSchedulePreview(
                  _displayedSchedules[index], subjectColors, index),
            ),
          ),
        );
      },
    );
  }

  // Construye la vista previa visual de un único horario en formato de cuadrícula.
  Widget buildSchedulePreview(List<ClassOption> schedule,
      Map<String, Color> subjectColors, int scheduleIndex) {
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

    final List<String> days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    // Matriz para almacenar las clases organizadas por día y hora.
    Map<String, Map<String, ClassOption?>> scheduleMatrix = {
      for (var time in timeSlots) time: {for (var day in days) day: null}
    };

    // Llena la matriz con las clases del horario.
    for (var classOption in schedule) {
      for (var sched in classOption.schedules) {
        TimeOfDayRange range = parseTimeRange(sched.time);
        String day = sched.day.substring(0, 3);

        if (!days.contains(day)) continue;

        int startIndex = getTimeSlotIndex(range.start, timeSlots);
        int endIndex = getTimeSlotIndex(range.end, timeSlots);

        if (startIndex == -1 || endIndex == -1) continue;

        for (int i = startIndex; i < endIndex; i++) {
          if (i < timeSlots.length) {
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

        double hourColumnWidth = totalWidth * 0.12;
        double dayColumnWidth = (totalWidth - hourColumnWidth) / days.length;
        double cellHeight = totalHeight / (timeSlots.length + 1);
        double fontSize = (cellHeight * 0.4).clamp(6.0, 12.0);

        return Column(
          children: [
            // Fila de encabezado con los nombres de los días.
            SizedBox(
              height: cellHeight,
              child: Row(
                children: [
                  // Celda de la esquina para mostrar el número del horario
                  Container(
                    width: hourColumnWidth,
                    height: cellHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      border: Border(
                        right:
                            BorderSide(color: Colors.grey.shade400, width: 1),
                        bottom:
                            BorderSide(color: Colors.grey.shade400, width: 1),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '#${scheduleIndex + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  ...days.map((day) => SizedBox(
                        width: dayColumnWidth,
                        child: Center(
                          child: Text(day,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: fontSize * 0.9)),
                        ),
                      )),
                ],
              ),
            ),
            // Cuerpo de la cuadrícula con las horas y las clases.
            Expanded(
              child: Row(
                children: [
                  // Columna de horas.
                  SizedBox(
                    width: hourColumnWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: timeSlots
                          .map((time) => Expanded(
                                child: Center(
                                  child: Text(time,
                                      style: TextStyle(
                                          fontSize: fontSize * 0.8,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  // Celdas para cada día de la semana.
                  Expanded(
                    child: Column(
                      children: timeSlots.map((time) {
                        return Expanded(
                          child: Row(
                            children: days.map((day) {
                              ClassOption? classOption =
                                  scheduleMatrix[time]![day];
                              Color? subjectColor = classOption != null
                                  ? subjectColors[classOption.subjectName]
                                  : null;

                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(0.5),
                                  decoration: BoxDecoration(
                                    color: classOption != null
                                        ? subjectColor
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: classOption != null
                                      ? Center(
                                          child: Text(
                                            //Se coloca el nombre hasta el primer espacio
                                            classOption.subjectName
                                                .split(' ')[0],
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: fontSize,
                                                fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Genera un mapa de colores único para cada materia en los horarios.
  Map<String, Color> _generateSubjectColors() {
    final List<Color> colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.amber,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.lime,
      Colors.deepOrange,
      Colors.lightBlue,
      Colors.lightGreen,
      Colors.deepPurple,
    ];

    Map<String, Color> subjectColors = {};
    int colorIndex = 0;

    Set<String> allSubjects = widget.allSchedules
        .expand((schedule) => schedule.map((co) => co.subjectName))
        .toSet();

    for (var subject in allSubjects) {
      subjectColors[subject] = colors[colorIndex % colors.length];
      colorIndex++;
    }

    return subjectColors;
  }

  /// Parsea una cadena de rango de tiempo (ej. "07:00 - 09:00") a un objeto TimeOfDayRange.
  TimeOfDayRange parseTimeRange(String timeRange) {
    List<String> parts = timeRange.split(' - ');
    return TimeOfDayRange(parseTimeOfDay(parts[0]), parseTimeOfDay(parts[1]));
  }

  /// Parsea una cadena de tiempo (ej. "07:00") a un objeto TimeOfDay.
  TimeOfDay parseTimeOfDay(String timeString) {
    final List<String> timeParts = timeString.split(':');
    final int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Encuentra el índice de una franja horaria correspondiente a una hora específica.
  int getTimeSlotIndex(TimeOfDay time, List<String> timeSlots) {
    // Si la hora de fin tiene minutos (ej. 14:50), se considera que ocupa
    // toda la franja horaria de la hora de inicio (ej. la franja de las 14:00).
    // Para que el bucle `i < endIndex` la incluya, el índice final debe ser
    // el de la siguiente hora.
    int hourToIndex = time.minute > 0 ? time.hour + 1 : time.hour;

    // La primera franja es a las 7:00, que corresponde al índice 0.
    int index = hourToIndex - 7;

    // El +1 es porque el endIndex puede ser el tamaño de la lista (para incluir la última franja).
    return index.clamp(0, timeSlots.length);
  }
}

/// Representa un rango de tiempo con una hora de inicio y una de fin.
class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);
}
