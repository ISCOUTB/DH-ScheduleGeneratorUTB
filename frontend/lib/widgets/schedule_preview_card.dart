// lib/widgets/schedule_preview_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_option.dart';
import '../providers/schedule_provider.dart';

/// Vista previa (cuadrícula compacta) de un único horario.
///
/// Extraída de `ScheduleGridWidget` para reutilizarse tal cual tanto en la
/// grilla paginada de escritorio como en el scroll lazy de móvil (SliverGrid),
/// sin duplicar la lógica de pintado.
class SchedulePreview extends StatelessWidget {
  final List<ClassOption> schedule;
  final Map<String, Color> subjectColors;
  final int scheduleIndex;

  /// Etiqueta de la celda esquina (ej: 'A'); si es null se usa `#index+1`.
  final String? labelOverride;

  /// Resuelve el color de relleno de cada bloque (p. ej. estado de cupos).
  /// Si es null se colorea por materia con [subjectColors].
  final Color Function(ClassOption)? colorResolver;

  const SchedulePreview({
    super.key,
    required this.schedule,
    required this.subjectColors,
    required this.scheduleIndex,
    this.labelOverride,
    this.colorResolver,
  });

  static const List<String> _timeSlots = [
    '07:00', '08:00', '09:00', '10:00', '11:00', '12:00', '13:00',
    '14:00', '15:00', '16:00', '17:00', '18:00', '19:00', '20:00',
  ];

  static const List<String> _days = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom',
  ];

  @override
  Widget build(BuildContext context) {
    // Matriz para almacenar las clases organizadas por día y hora.
    final Map<String, Map<String, ClassOption?>> scheduleMatrix = {
      for (var time in _timeSlots) time: {for (var day in _days) day: null}
    };

    // Llena la matriz con las clases del horario.
    for (var classOption in schedule) {
      for (var sched in classOption.schedules) {
        final _TimeRange range = _parseTimeRange(sched.time);
        final String day = sched.day.substring(0, 3);

        if (!_days.contains(day)) continue;

        final int startIndex = _getTimeSlotIndex(range.start);
        final int endIndex = _getTimeSlotIndex(range.end);

        if (startIndex == -1 || endIndex == -1) continue;

        for (int i = startIndex; i < endIndex; i++) {
          if (i < _timeSlots.length) {
            scheduleMatrix[_timeSlots[i]]![day] = classOption;
          }
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tamaños de celda y fuente adaptativos según el espacio disponible.
        final double totalWidth = constraints.maxWidth;
        final double totalHeight = constraints.maxHeight;

        final double hourColumnWidth = totalWidth * 0.12;
        final double dayColumnWidth = (totalWidth - hourColumnWidth) / _days.length;
        final double cellHeight = totalHeight / (_timeSlots.length + 1);
        final double fontSize = (cellHeight * 0.4).clamp(6.0, 12.0);

        return Column(
          children: [
            // Fila de encabezado con los nombres de los días.
            SizedBox(
              height: cellHeight,
              child: Row(
                children: [
                  // Celda de la esquina con el número/letra del horario.
                  Container(
                    width: hourColumnWidth,
                    height: cellHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      border: Border(
                        right: BorderSide(color: Colors.grey.shade400, width: 1),
                        bottom: BorderSide(color: Colors.grey.shade400, width: 1),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        labelOverride ?? '#${scheduleIndex + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  ..._days.map((day) => SizedBox(
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
                      children: _timeSlots
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
                      children: _timeSlots.map((time) {
                        return Expanded(
                          child: Row(
                            children: _days.map((day) {
                              final ClassOption? classOption =
                                  scheduleMatrix[time]![day];
                              // colorResolver (ej. estado de cupos) tiene
                              // prioridad sobre el color por materia.
                              final Color? subjectColor = classOption != null
                                  ? (colorResolver != null
                                      ? colorResolver!(classOption)
                                      : subjectColors[classOption.subjectKey])
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
                                            // Nombre hasta el primer espacio.
                                            classOption.subjectName.split(' ')[0],
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

  _TimeRange _parseTimeRange(String timeRange) {
    final parts = timeRange.split(' - ');
    return _TimeRange(_parseTimeOfDay(parts[0]), _parseTimeOfDay(parts[1]));
  }

  TimeOfDay _parseTimeOfDay(String timeString) {
    final timeParts = timeString.split(':');
    return TimeOfDay(
        hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
  }

  int _getTimeSlotIndex(TimeOfDay time) {
    // Si la hora de fin tiene minutos (ej. 14:50), ocupa toda la franja de la
    // hora de inicio; el índice final debe ser el de la siguiente hora.
    final int hourToIndex = time.minute > 0 ? time.hour + 1 : time.hour;
    final int index = hourToIndex - 7; // La primera franja (07:00) es el índice 0.
    return index.clamp(0, _timeSlots.length);
  }
}

class _TimeRange {
  final TimeOfDay start;
  final TimeOfDay end;
  const _TimeRange(this.start, this.end);
}

/// Tarjeta completa de un horario: [SchedulePreview] dentro de un `Card` con la
/// estrella de favoritos opcional y el tap. Es la unidad que renderizan tanto
/// la grilla paginada como el scroll lazy móvil.
class SchedulePreviewCard extends StatelessWidget {
  final List<ClassOption> schedule;
  final Map<String, Color> subjectColors;
  final int scheduleIndex;
  final String? labelOverride;
  final Color Function(ClassOption)? colorResolver;
  final bool showFavoriteButton;
  final VoidCallback onTap;

  const SchedulePreviewCard({
    super.key,
    required this.schedule,
    required this.subjectColors,
    required this.scheduleIndex,
    required this.onTap,
    this.labelOverride,
    this.colorResolver,
    this.showFavoriteButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Stack(
            children: [
              SchedulePreview(
                schedule: schedule,
                subjectColors: subjectColors,
                scheduleIndex: scheduleIndex,
                labelOverride: labelOverride,
                colorResolver: colorResolver,
              ),
              if (showFavoriteButton)
                Positioned(
                  top: 2,
                  right: 2,
                  child: ScheduleFavoriteStar(schedule: schedule),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estrella para marcar/desmarcar un horario como favorito.
class ScheduleFavoriteStar extends StatelessWidget {
  final List<ClassOption> schedule;

  const ScheduleFavoriteStar({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final isFav = provider.isFavorite(schedule);

    return GestureDetector(
      // Evita que el tap en la estrella abra el overview del horario.
      onTap: () => provider.toggleFavorite(schedule),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          isFav ? Icons.star : Icons.star_border,
          color: isFav ? Colors.amber : Colors.white70,
          size: 18,
        ),
      ),
    );
  }
}
