// lib/widgets/schedule_overview_widget.dart
import 'package:flutter/material.dart';
import '../models/class_option.dart';
import 'package:excel/excel.dart' as excel; 
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import '../utils/file_utils.dart';

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
    'Domingo',
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
    final Map<String, List<ClassOption>> groupedSubjects =
        groupBy(widget.schedule, (ClassOption option) => option.subjectName);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      // Aumentamos el ancho para acomodar el diseño de dos columnas
      child: Container(
        width: 1100,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detalles del Horario',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Tooltip(
                      message: 'Descargar PDF',
                      child: IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        onPressed: downloadScheduleAsPDF,
                      ),
                    ),
                    Tooltip(
                      message: 'Descargar Excel',
                      child: IconButton(
                        icon: const Icon(Icons.table_chart_outlined),
                        onPressed: downloadScheduleAsExcel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            // --- DIVIDIR EL ESPACIO EN DOS COLUMNAS ---
            // Usamos un Row con Expanded para dividir el espacio en dos columnas
            Expanded(
              child: Row(
                children: [
                  // --- COLUMNA IZQUIERDA: VISTA DE LA CUADRÍCULA DEL HORARIO ---
                  Expanded(
                    flex: 3, // Ocupa 3/5 del espacio
                    child: _buildScheduleGrid(),
                  ),

                  const VerticalDivider(width: 24),

                  // --- COLUMNA DERECHA: DETALLES DESPLEGABLES ---
                  Expanded(
                    flex: 2, // Ocupa 2/5 del espacio
                    child: ListView.builder(
                      itemCount: groupedSubjects.length,
                      itemBuilder: (context, index) {
                        final subjectName =
                            groupedSubjects.keys.elementAt(index);
                        final classOptions = groupedSubjects[subjectName]!;
                        final color = subjectColors[subjectName] ?? Colors.grey;

                        // ExpansionTile para el efecto desplegable
                        return ExpansionTile(
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            subjectName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          // Contenido que se muestra al expandir
                          children: classOptions.map((option) {
                            return ListTile(
                              contentPadding: const EdgeInsets.only(
                                  left: 40, right: 16, bottom: 8),
                              title: Text('${option.type} (NRC: ${option.nrc})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                'Profesor: ${option.professor}\n'
                                'Horario: ${option.schedules.map((s) => '${s.day} ${s.time}').join(" | ")}\n'
                                'Créditos: ${option.credits}',
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET DE CUADRÍCULA VISUAL (REESTRUCTURADO PARA AJUSTE AUTOMÁTICO) ---
  Widget _buildScheduleGrid() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7.0),
        child: Column(
          children: [
            // Fila de encabezado de días (fija)
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  const SizedBox(width: 50), // Espacio para la columna de hora
                  ...days.map((day) => Expanded(
                        child: Center(
                          child: Text(day.substring(0, 3),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )),
                ],
              ),
            ),
            // Cuadrícula principal (se expande para llenar el espacio)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calcula la altura de la fila dinámicamente para que no haya scroll
                  final double hourRowHeight =
                      constraints.maxHeight / timeSlots.length;
                  final double dayColumnWidth =
                      (constraints.maxWidth - 50) / days.length;
                  final double gridHeight = constraints.maxHeight;

                  return Stack(
                    children: [
                      // Fondo de la cuadrícula con horas y líneas
                      SizedBox(
                        height: gridHeight,
                        child: Column(
                          children: timeSlots.map((time) {
                            return Container(
                              height: hourRowHeight, // Usa la altura dinámica
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                      color: Colors.grey.shade300, width: 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 50,
                                    child: Center(
                                      child: Text(
                                        time,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  ...days.map((day) => Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              left: BorderSide(
                                                  color: Colors.grey.shade200,
                                                  width: 1),
                                            ),
                                          ),
                                        ),
                                      )),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Bloques de clases superpuestos
                      SizedBox(
                        height: gridHeight,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 50.0),
                          child: Stack(
                            children: _buildClassBlocks(
                                hourRowHeight, dayColumnWidth),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construir los bloques de clases superpuestos
  // Esta función crea los widgets que representan las clases en la cuadrícula.
  List<Widget> _buildClassBlocks(double hourRowHeight, double dayColumnWidth) {
    List<Widget> blocks = [];
    for (var classOption in widget.schedule) {
      final color = subjectColors[classOption.subjectName] ?? Colors.grey;
      for (var scheduleItem in classOption.schedules) {
        final dayIndex = days.indexOf(scheduleItem.day);
        if (dayIndex == -1) continue;

        final timeRange = parseTimeRange(scheduleItem.time);
        final startHour = timeRange.start.hour + timeRange.start.minute / 60.0;
        final endHour = timeRange.end.hour + timeRange.end.minute / 60.0;

        final top = (startHour - 7) * hourRowHeight;
        final height = (endHour - startHour) * hourRowHeight;
        final left = dayIndex * dayColumnWidth;

        if (top >= 0 && height > 0) {
          blocks.add(
            Positioned(
              top: top,
              left: left,
              width: dayColumnWidth - 2, // Pequeño margen
              height: height,
              child: Container(
                margin: const EdgeInsets.all(1),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  classOption.subjectName,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
          );
        }
      }
    }
    return blocks;
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

    // Crear un nuevo archivo Excel
    var excelFile = excel.Excel.createExcel();
    excel.Sheet sheetObject = excelFile['Horario'];

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
    List<int>? excelBytes = excelFile.encode();

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
  bool isTimeWithinRange(TimeOfDay time, TimeOfDayRange range) =>
      (time.hour * 60 + time.minute) >=
          (range.start.hour * 60 + range.start.minute) &&
      (time.hour * 60 + time.minute) < (range.end.hour * 60 + range.end.minute);

  // Funciones para parsear los horarios
  TimeOfDayRange parseTimeRange(String timeRange) {
    final List<String> parts = timeRange.split(' - ');
    final TimeOfDay start = parseTimeOfDay(parts[0].trim());
    final TimeOfDay end = parseTimeOfDay(parts[1].trim());
    return TimeOfDayRange(start, end);
  }

  TimeOfDay parseTimeOfDay(String timeString) {
    // Eliminar espacios y convertir a mayúsculas
    timeString = timeString.trim().toUpperCase();

    // Verificar si contiene 'AM' o 'PM'
    final bool isPM = timeString.contains('PM');
    final bool isAM = timeString.contains('AM');

    // Eliminar 'AM' y 'PM' si están presentes
    timeString = timeString.replaceAll('AM', '').replaceAll('PM', '').trim();

    // Separar horas y minutos
    final List<String> timeParts = timeString.split(':');
    int hour = int.parse(timeParts[0]);
    final int minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

    // Convertir a formato de 24 horas si es necesario
    if (isPM && hour < 12) {
      hour += 12;
    }
    if (isAM && hour == 12) {
      // Medianoche (12 AM) es la hora 0
      hour = 0;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }
}

// Definición de TimeOfDayRange
class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);
}
