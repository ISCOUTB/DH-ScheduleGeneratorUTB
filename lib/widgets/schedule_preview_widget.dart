// lib/widgets/schedule_overview_widget.dart (copia para pruebas en desuso)
import 'package:flutter/material.dart';
import '../models/class_option.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'dart:html' as html; // Import necesario para Flutter Web
import 'package:flutter/services.dart' show rootBundle;
import 'package:collection/collection.dart';

class ScheduleOverviewWidget extends StatefulWidget {
  final List<List<ClassOption>> allSchedules; // Lista de todos los horarios
  final int currentIndex; // Índice del horario actual
  final VoidCallback onClose;

  const ScheduleOverviewWidget({
    Key? key,
    required this.allSchedules,
    required this.currentIndex,
    required this.onClose,
  }) : super(key: key);

  @override
  _ScheduleOverviewWidgetState createState() => _ScheduleOverviewWidgetState();
}

class _ScheduleOverviewWidgetState extends State<ScheduleOverviewWidget> {
  // Controladores de scroll
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Índice y horario actual
  late int _currentIndex;
  late List<ClassOption> _currentSchedule;

  // Definir los horarios y días (en formato de 24 horas)
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
    '21:00',
  ];

  final List<String> days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _currentSchedule = widget.allSchedules[_currentIndex];
  }

  @override
  void dispose() {
    // Liberar los controladores de scroll cuando el widget se elimina
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _navigateSchedule(int direction) {
    int newIndex = _currentIndex + direction;
    if (newIndex >= 0 && newIndex < widget.allSchedules.length) {
      setState(() {
        _currentIndex = newIndex;
        _currentSchedule = widget.allSchedules[_currentIndex];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Crear la matriz del horario
    Map<String, Map<String, ClassOption?>> scheduleMatrix = {};

    for (String time in timeSlots) {
      scheduleMatrix[time] = {};
      for (String day in days) {
        scheduleMatrix[time]![day] = null; // Inicialmente vacío
      }
    }

    // Llenar la matriz del horario con las clases
    for (var classOption in _currentSchedule) {
      for (var sched in classOption.schedules) {
        TimeOfDayRange range = parseTimeRange(sched.time);
        String day = sched.day;

        int startIndex = getStartTimeSlotIndex(range.start, timeSlots);
        int endIndex = getEndTimeSlotIndex(range.end, timeSlots);

        if (startIndex == -1 || endIndex == -1) continue;

        // Llenamos los bloques de tiempo entre el inicio y el fin de la clase
        for (int i = startIndex; i < endIndex; i++) {
          if (i < timeSlots.length) {
            scheduleMatrix[timeSlots[i]]![day] = classOption;
          }
        }
      }
    }

    // Obtener las materias únicas
    final subjects = _currentSchedule;

    return Dialog(
      child: Container(
        width: 1000,
        height: 800,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Botones de navegación y cierre
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botón de navegación izquierda
                IconButton(
                  icon: Icon(
                    Icons.arrow_left,
                    size: 30,
                    color: _currentIndex > 0 ? Colors.black : Colors.grey,
                  ),
                  onPressed: _currentIndex > 0 ? () => _navigateSchedule(-1) : null,
                  tooltip: 'Horario anterior',
                ),
                // Botón de cierre
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: 'Cerrar',
                ),
                // Botón de navegación derecha
                IconButton(
                  icon: Icon(
                    Icons.arrow_right,
                    size: 30,
                    color: _currentIndex < widget.allSchedules.length - 1
                        ? Colors.black
                        : Colors.grey,
                  ),
                  onPressed: _currentIndex < widget.allSchedules.length - 1
                      ? () => _navigateSchedule(1)
                      : null,
                  tooltip: 'Siguiente horario',
                ),
              ],
            ),
            // Botones para descargar Excel y PDF
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => downloadScheduleAsExcel(),
                  child: Text('Descargar Excel'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => downloadScheduleAsPDF(),
                  child: Text('Descargar PDF'),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Widget del horario
            Expanded(
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 1000),
                    child: Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          border: TableBorder(
                            verticalInside: BorderSide(width: 1, color: Colors.grey),
                          ),
                          columnSpacing: 20,
                          columns: [
                            const DataColumn(label: Text('Horario')),
                            ...days.map((day) => DataColumn(label: Text(day))),
                          ],
                          rows: timeSlots.map((time) {
                            return DataRow(cells: [
                              DataCell(Text('$time')),
                              ...days.map((day) {
                                var classOption = scheduleMatrix[time]![day];
                                if (classOption != null) {
                                  return DataCell(
                                    Center(
                                      child: Container(
                                        margin: const EdgeInsets.all(3),
                                        color: Colors.lightBlueAccent,
                                        width: 90,
                                        padding: const EdgeInsets.all(4),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              classOption.subjectName,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              '${classOption.type}\n${classOption.professor}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  return const DataCell(Text(''));
                                }
                              }).toList(),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
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
                              Text(
                                  'Horario completo: ${classOption.schedules.map((s) => s.day + ' ' + s.time).join(', ')}'),
                              Text('Número de créditos: ${classOption.credits}'),
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
          ],
        ),
      ),
    );
  }

  Future<void> downloadScheduleAsExcel() async {
    try {
      var bytes = await _generateExcel({
        'schedule': _currentSchedule,
        'timeSlots': timeSlots,
        'days': days,
      });

      // Crear un Blob y descargar el archivo
      final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'horario.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Descargando archivo Excel')),
      );
    } catch (e) {
      print('Error al generar el Excel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar el Excel')),
      );
    }
  }

  Future<void> downloadScheduleAsPDF() async {
    try {
      // Generar el PDF de forma asíncrona
      final bytes = await _generatePDF({
        'schedule': _currentSchedule,
        'timeSlots': timeSlots,
        'days': days,
      });

      // Crear un Blob y descargar el archivo
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'horario.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Descargando archivo PDF')),
      );
    } catch (e) {
      print('Error al generar el PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar el PDF')),
      );
    }
  }

  // Funciones auxiliares

  // Función para obtener el índice del timeSlot de inicio
  int getStartTimeSlotIndex(TimeOfDay time, List<String> timeSlots) {
    int timeMinutes = time.hour * 60 + time.minute;

    for (int i = 0; i < timeSlots.length; i++) {
      TimeOfDay slotTime = parseTimeOfDay(timeSlots[i]);
      int slotMinutes = slotTime.hour * 60 + slotTime.minute;

      if (timeMinutes <= slotMinutes) {
        return i;
      }
    }
    return timeSlots.length - 1;
  }

  // Función para obtener el índice del timeSlot de fin
  int getEndTimeSlotIndex(TimeOfDay time, List<String> timeSlots) {
    int timeMinutes = time.hour * 60 + time.minute;

    for (int i = 0; i < timeSlots.length; i++) {
      TimeOfDay slotTime = parseTimeOfDay(timeSlots[i]);
      int slotMinutes = slotTime.hour * 60 + slotTime.minute;

      if (timeMinutes <= slotMinutes) {
        return i;
      }
    }
    return timeSlots.length;
  }

  // Función para parsear un rango de tiempo
  TimeOfDayRange parseTimeRange(String timeRange) {
    List<String> parts = timeRange.split(' - ');
    TimeOfDay start = parseTimeOfDay(parts[0].trim());
    TimeOfDay end = parseTimeOfDay(parts[1].trim());
    return TimeOfDayRange(start, end);
  }

  // Función para parsear un TimeOfDay desde un String
  TimeOfDay parseTimeOfDay(String timeString) {
    // Eliminar espacios y convertir a mayúsculas
    timeString = timeString.trim().toUpperCase();

    // Verificar si contiene 'AM' o 'PM'
    bool isPM = timeString.contains('PM');
    bool isAM = timeString.contains('AM');

    // Eliminar 'AM' y 'PM' si están presentes
    timeString = timeString.replaceAll('AM', '').replaceAll('PM', '').trim();

    // Separar horas y minutos
    List<String> timeParts = timeString.split(':');
    int hour = int.parse(timeParts[0]);
    int minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

    // Convertir a formato de 24 horas si es necesario
    if (isPM && hour < 12) {
      hour += 12;
    }
    if (isAM && hour == 12) {
      hour = 0;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  // Añade la función isTimeWithinRange
  bool isTimeWithinRange(TimeOfDay time, TimeOfDayRange range) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = range.start.hour * 60 + range.start.minute;
    final endMinutes = range.end.hour * 60 + range.end.minute;

    return timeMinutes >= startMinutes && timeMinutes < endMinutes;
  }

  // Funciones para generar Excel y PDF
  Future<Uint8List> _generateExcel(Map<String, dynamic> params) async {
    List<ClassOption> schedule = params['schedule'];
    List<String> timeSlots = params['timeSlots'];
    List<String> days = params['days'];

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Horario'];

    // Encabezados
    sheetObject.appendRow(['Horario', ...days]);

    for (var timeSlot in timeSlots) {
      List<String?> row = [timeSlot];
      TimeOfDay timeSlotTime = parseTimeOfDay(timeSlot);
      for (var day in days) {
        ClassOption? classOption = schedule.firstWhereOrNull(
          (co) => co.schedules.any(
            (s) {
              if (s.day != day) return false;
              TimeOfDayRange range = parseTimeRange(s.time);
              return isTimeWithinRange(timeSlotTime, range);
            },
          ),
        );
        row.add(classOption?.subjectName ?? '');
      }
      sheetObject.appendRow(row);
    }

    // Codifica el archivo Excel en bytes
    List<int>? excelBytes = excel.encode();

    // Retorna los bytes como Uint8List
    return Uint8List.fromList(excelBytes!);
  }

  Future<Uint8List> _generatePDF(Map<String, dynamic> params) async {
    List<ClassOption> schedule = params['schedule'];
    List<String> timeSlots = params['timeSlots'];
    List<String> days = params['days'];

    final pdf = pw.Document();

    // Cargar la fuente personalizada
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Table.fromTextArray(
            headers: ['Horario', ...days],
            data: [
              for (var timeSlot in timeSlots)
                [
                  timeSlot,
                  ...days.map((day) {
                    TimeOfDay timeSlotTime = parseTimeOfDay(timeSlot);
                    ClassOption? classOption = schedule.firstWhereOrNull(
                      (co) => co.schedules.any(
                        (s) {
                          if (s.day != day) return false;
                          TimeOfDayRange range = parseTimeRange(s.time);
                          return isTimeWithinRange(timeSlotTime, range);
                        },
                      ),
                    );
                    return classOption?.subjectName ?? '';
                  }).toList(),
                ]
            ],
            cellStyle: pw.TextStyle(font: ttf),
            headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold),
          );
        },
      ),
    );

    return await pdf.save();
  }
}

// Definición de TimeOfDayRange
class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);
}
