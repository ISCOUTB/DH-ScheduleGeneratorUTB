// lib/widgets/schedule_overview_widget.dart
import 'package:flutter/material.dart';
import '../models/class_option.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import '../utils/file_utils.dart'; // Importamos nuestra utilidad de archivos
import '../utils/schedule_generator.dart';

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
  // Mapa de colores para las materias
  late Map<String, Color> subjectColors;

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
    // Generar el mapa de colores para las materias
    subjectColors = _generateSubjectColors();
  }

  @override
  Widget build(BuildContext context) {
    // Agrupar las materias y sus opciones
    Map<String, List<ClassOption>> groupedSubjects = {};

    for (var classOption in widget.schedule) {
      String subjectName = classOption.subjectName;
      if (!groupedSubjects.containsKey(subjectName)) {
        groupedSubjects[subjectName] = [];
      }
      groupedSubjects[subjectName]!.add(classOption);
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(10), // Esquinas redondeadas del diálogo
      ),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ajustar el tamaño al contenido
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detalles del horario',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.picture_as_pdf),
                      tooltip: 'Descargar PDF',
                      onPressed: downloadScheduleAsPDF,
                    ),
                    IconButton(
                      icon: Icon(Icons.table_chart),
                      tooltip: 'Descargar Excel',
                      onPressed: downloadScheduleAsExcel,
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      tooltip: 'Cerrar',
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            // Botones de materias con ícono de información
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: groupedSubjects.entries.map((entry) {
                String subjectName = entry.key;
                List<ClassOption> classOptions = entry.value;

                return ElevatedButton.icon(
                  onPressed: () {
                    // Mostrar información de la materia
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text(subjectName),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: classOptions.map((classOption) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tipo: ${classOption.type}'),
                                    Text('Profesor: ${classOption.professor}'),
                                    Text(
                                      'Horario: ${classOption.schedules.map((s) => s.day + ' ' + s.time).join(', ')}',
                                    ),
                                    Text('NRC: ${classOption.nrc}'),
                                    Text(
                                        'Número de créditos: ${classOption.credits}'),
                                    SizedBox(height: 8),
                                  ],
                                );
                              }).toList(),
                            ),
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
                  label: Text(subjectName),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Generar un mapa de colores para las materias
  Map<String, Color> _generateSubjectColors() {
    List<Color> colors = [
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

    // Obtener todas las materias del horario actual
    Set<String> allSubjects = {};
    for (var classOption in widget.schedule) {
      allSubjects.add(classOption.subjectName);
    }

    for (var subject in allSubjects) {
      subjectColors[subject] = colors[colorIndex % colors.length];
      colorIndex++;
    }

    return subjectColors;
  }

  Future<void> downloadScheduleAsExcel() async {
    try {
      var bytes = await _generateExcel({
        'schedule': widget.schedule,
        'timeSlots': timeSlots,
        'days': days,
      });

      await saveAndOpenFile(bytes, 'horario.xlsx');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo Excel generado exitosamente')),
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
      final bytes = await _generatePDF({
        'schedule': widget.schedule,
        'timeSlots': timeSlots,
        'days': days,
      });

      await saveAndOpenFile(bytes, 'horario.pdf');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo PDF generado exitosamente')),
      );
    } catch (e) {
      print('Error al generar el PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar el PDF')),
      );
    }
  }

  // Funciones auxiliares para generar los archivos

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
        // Concatenar subjectName y nrc si existe la opción
        if (classOption != null) {
          row.add('${classOption.subjectName}\nNRC: ${classOption.nrc}');
        } else
          row.add('');
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

    // Cargar la fuente predeterminada
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
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
                    if (classOption != null) {
                      return '${classOption.subjectName}\nNRC: ${classOption.nrc}';
                    } else
                      return '';
                  }).toList(),
                ]
            ],
            cellStyle: pw.TextStyle(font: ttf, fontSize: 10),
            headerStyle: pw.TextStyle(
                font: ttf, fontWeight: pw.FontWeight.bold, fontSize: 12),
            cellAlignment: pw.Alignment.center,
            headerAlignment: pw.Alignment.center,
          );
        },
      ),
    );
    return await pdf.save();
  }

  // Funciones auxiliares

  //Función isTimeWithinRange
  bool isTimeWithinRange(TimeOfDay time, TimeOfDayRange range) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = range.start.hour * 60 + range.start.minute;
    final endMinutes = range.end.hour * 60 + range.end.minute;

    return timeMinutes >= startMinutes && timeMinutes < endMinutes;
  }

  // Funciones para parsear los horarios
  TimeOfDayRange parseTimeRange(String timeRange) {
    List<String> parts = timeRange.split(' - ');
    TimeOfDay start = parseTimeOfDay(parts[0].trim());
    TimeOfDay end = parseTimeOfDay(parts[1].trim());
    return TimeOfDayRange(start, end);
  }

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
}
