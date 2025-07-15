// lib/widgets/schedule_overview_widget.dart
import 'package:flutter/material.dart';
import '../models/class_option.dart';
import '../models/schedule.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import '../utils/file_utils.dart';

/// Un widget que muestra una vista detallada de un horario específico.
///
/// Presenta el horario en una cuadrícula visual y una lista detallada de las clases.
/// También permite exportar el horario a formatos PDF y Excel.
class ScheduleOverviewWidget extends StatefulWidget {
  /// El horario a mostrar, compuesto por una lista de opciones de clase.
  final List<ClassOption> schedule;

  /// Callback para cerrar la vista de detalle.
  final VoidCallback onClose;

  const ScheduleOverviewWidget({
    Key? key,
    required this.schedule,
    required this.onClose,
  }) : super(key: key);

  @override
  _ScheduleOverviewWidgetState createState() => _ScheduleOverviewWidgetState();
}

String formattingSchedulesInPairs(List<Schedule> horarios) {
  List<String> lineas = [];
  for (int i = 0; i < horarios.length; i += 2) {
    String linea = '${horarios[i].day} ${horarios[i].time}';
    if (i + 1 < horarios.length) {
      linea += ' | ${horarios[i + 1].day} ${horarios[i + 1].time}';
    }
    lineas.add(linea);
  }
  // Alineamos todas las líneas debajo de la primera con sangría
  String sangria = '               '; // mismo largo que 'Horario: '
  return lineas
      .asMap()
      .entries
      .map((entry) => entry.key == 0 ? entry.value : '$sangria${entry.value}')
      .join('\n');
}

class _ScheduleOverviewWidgetState extends State<ScheduleOverviewWidget> {
  /// Mapa de colores asignados a cada materia para una fácil identificación visual.
  late Map<String, Color> subjectColors;

  /// Lista de franjas horarias que se muestran en la cuadrícula del horario.
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

  /// Lista de días de la semana para las columnas de la cuadrícula.
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
    // Genera los colores para las materias al iniciar el widget.
    subjectColors = _generateSubjectColors();
  }

  @override
  Widget build(BuildContext context) {
    // Agrupa las clases por nombre de materia para la lista de detalles.
    final Map<String, List<ClassOption>> groupedSubjects =
        groupBy(widget.schedule, (ClassOption option) => option.subjectName);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      // Aumenta el ancho para acomodar el diseño de dos columnas
      child: Container(
        width: 1333,
        height:
            500, // Usamos una altura fija en lugar de una relativa a la pantalla.
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
                    // Botón para descargar el horario en formato PDF.
                    Tooltip(
                      message: 'Descargar PDF',
                      child: IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        onPressed: downloadScheduleAsPDF,
                      ),
                    ),
                    // Botón para descargar el horario en formato Excel.
                    Tooltip(
                      message: 'Descargar Excel',
                      child: IconButton(
                        icon: const Icon(Icons.table_chart_outlined),
                        onPressed: downloadScheduleAsExcel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Botón para cerrar la vista de detalle.
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

            // Layout principal de dos columnas: cuadrícula a la izquierda, detalles a la derecha.
            Expanded(
              child: Row(
                children: [
                  // Columna izquierda: Cuadrícula visual del horario.
                  Expanded(
                    flex: 3, // Ocupa 3/5 del espacio
                    child: _buildScheduleGrid(),
                  ),

                  const VerticalDivider(width: 24),

                  // Columna derecha: Lista desplegable con los detalles de cada materia.
                  Expanded(
                    flex: 2, // Ocupa 2/5 del espacio
                    child: ListView.builder(
                      itemCount: groupedSubjects.length,
                      itemBuilder: (context, index) {
                        final subjectName =
                            groupedSubjects.keys.elementAt(index);
                        final classOptions = groupedSubjects[subjectName]!;
                        final color = subjectColors[subjectName] ?? Colors.grey;

                        // Cada materia es un ExpansionTile que muestra los detalles al expandirse.
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
                          // Muestra los detalles de la clase (NRC, profesor, etc.) al expandir.
                          children: classOptions.map((option) {
                            return ListTile(
                              contentPadding: const EdgeInsets.only(
                                  left: 40, right: 16, bottom: 8),
                              title: Text('${option.type} (NRC: ${option.nrc})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                'Profesor: ${option.professor}\n'
                                'Horario: ${formattingSchedulesInPairs(option.schedules)}\n'
                                'Campus: ${option.campus}\n'
                                'Cupos: ${option.seatsAvailable} de ${option.seatsMaximum}\n'
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

  /// Construye la cuadrícula visual del horario con sus ejes de tiempo y días.
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
            // Fila de encabezado con los nombres de los días.
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
            // Contenedor principal de la cuadrícula que se ajusta al espacio disponible.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calcula dinámicamente la altura de las filas para evitar el desbordamiento.
                  final double hourRowHeight =
                      constraints.maxHeight / timeSlots.length;
                  final double dayColumnWidth =
                      (constraints.maxWidth - 50) / days.length;
                  final double gridHeight = constraints.maxHeight;

                  return Stack(
                    children: [
                      // Dibuja el fondo de la cuadrícula con las líneas de hora.
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
                      // Superpone los bloques de clase sobre la cuadrícula.
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

  /// Crea la lista de widgets (bloques) que representan cada clase en la cuadrícula.
  List<Widget> _buildClassBlocks(double hourRowHeight, double dayColumnWidth) {
    List<Widget> blocks = [];

    // Agrupa las clases por día y hora para detectar superposiciones
    Map<String, List<ClassOption>> classesByDayAndTime = {};

    for (var classOption in widget.schedule) {
      for (var scheduleItem in classOption.schedules) {
        String key = '${scheduleItem.day}_${scheduleItem.time}';
        if (!classesByDayAndTime.containsKey(key)) {
          classesByDayAndTime[key] = [];
        }
        classesByDayAndTime[key]!.add(classOption);
      }
    }

    // Procesa cada grupo de clases
    for (var entry in classesByDayAndTime.entries) {
      String key = entry.key;
      List<ClassOption> overlappingClasses = entry.value;

      String day = key.split('_')[0];
      String time = key.split('_')[1];

      final dayIndex = days.indexOf(day);
      if (dayIndex == -1) continue;

      // Calcula la posición y el tamaño del bloque en función de la hora y el día.
      final timeRange = parseTimeRange(time);
      final startHour = timeRange.start.hour + timeRange.start.minute / 60.0;
      final endHour = timeRange.end.hour + timeRange.end.minute / 60.0;

      final top = (startHour - 7) * hourRowHeight;
      final height = (endHour - startHour) * hourRowHeight;
      final left = dayIndex * dayColumnWidth;

      if (top >= 0 && height > 0) {
        // Obtener el color de la primera clase (todas las clases superpuestas de la misma materia tendrán el mismo color)
        final color =
            subjectColors[overlappingClasses.first.subjectName] ?? Colors.grey;

        // Crear un texto con todos los NRC separados por nueva línea
        String allNRCs =
            overlappingClasses.map((classOption) => classOption.nrc).join('\n');

        blocks.add(
          Positioned(
            top: top,
            left: left,
            width: dayColumnWidth - 2, // Margen para evitar superposición
            height: height,
            child: Container(
              margin: const EdgeInsets.all(1),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                allNRCs,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: overlappingClasses
                    .length, // Permitir tantas líneas como NRC haya
                textAlign: TextAlign.left,
              ),
            ),
          ),
        );
      }
    }
    return blocks;
  }

  /// Genera un mapa de colores único para cada materia del horario.
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

    // Extrae los nombres de materias únicos del horario actual.
    Set<String> allSubjects = {};
    for (var classOption in widget.schedule) {
      allSubjects.add(classOption.subjectName);
    }

    // Asigna un color a cada materia de forma cíclica.
    for (var subject in allSubjects) {
      subjectColors[subject] = colors[colorIndex % colors.length];
      colorIndex++;
    }

    return subjectColors;
  }

  /// Inicia la descarga del horario en formato Excel.
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

  /// Inicia la descarga del horario en formato PDF.
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

  // --- Funciones auxiliares para la generación de archivos ---

  /// Genera los bytes de un archivo Excel a partir de los datos del horario.
  Future<Uint8List> _generateExcel(Map<String, dynamic> params) async {
    List<ClassOption> schedule = params['schedule'];
    List<String> timeSlots = params['timeSlots'];
    List<String> days = params['days'];

    // Crea un nuevo archivo y hoja de Excel.
    var excelFile = excel.Excel.createExcel();
    excel.Sheet sheetObject = excelFile['Horario'];

    // Agrega la fila de encabezado.
    sheetObject.appendRow(['Horario', ...days]);

    // Llena cada fila con la materia correspondiente a la hora y día.
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

    // Codifica y retorna los bytes del archivo.
    List<int>? excelBytes = excelFile.encode();

    // Retorna los bytes como Uint8List
    return Uint8List.fromList(excelBytes!);
  }

  /// Genera los bytes de un archivo PDF a partir de los datos del horario.
  Future<Uint8List> _generatePDF(Map<String, dynamic> params) async {
    List<ClassOption> schedule = params['schedule'];
    List<String> timeSlots = params['timeSlots'];
    List<String> days = params['days'];

    final pdf = pw.Document();

    // Carga una fuente compatible con PDF.
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          // Crea una tabla con los datos del horario.
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
    // Guarda y retorna los bytes del documento PDF.
    return await pdf.save();
  }

  // --- Funciones auxiliares de utilidad ---

  /// Verifica si una hora específica se encuentra dentro de un rango de tiempo.
  bool isTimeWithinRange(TimeOfDay time, TimeOfDayRange range) =>
      (time.hour * 60 + time.minute) >=
          (range.start.hour * 60 + range.start.minute) &&
      (time.hour * 60 + time.minute) < (range.end.hour * 60 + range.end.minute);

  /// Parsea una cadena de rango de tiempo (ej. "07:00 - 09:00") a un objeto TimeOfDayRange.
  TimeOfDayRange parseTimeRange(String timeRange) {
    final List<String> parts = timeRange.split(' - ');
    final TimeOfDay start = parseTimeOfDay(parts[0].trim());
    final TimeOfDay end = parseTimeOfDay(parts[1].trim());
    return TimeOfDayRange(start, end);
  }

  /// Parsea una cadena de tiempo (ej. "7:00 AM") a un objeto TimeOfDay en formato de 24 horas.
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

/// Representa un rango de tiempo con una hora de inicio y fin.
class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);
}
