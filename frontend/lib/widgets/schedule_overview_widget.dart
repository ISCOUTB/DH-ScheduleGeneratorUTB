// lib/widgets/schedule_overview_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_option.dart';
import '../models/schedule.dart';
import '../models/course_status.dart';
import '../providers/schedule_provider.dart';
import 'color_mode_toggle.dart';
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

  /// Mapa de colores para las materias.
  final Map<String, Color> subjectColors;

  /// Cupos actuales por NRC `{ nrc: {available, total} }`, para colorear por
  /// estado. Solo se usa si [statusAvailable] es true.
  final Map<String, Map<String, int>> seatsByNrc;

  /// Si está disponible el coloreo por estado de cupos (solo término actual).
  /// Cuando es false, no se muestra el toggle y se colorea por materia.
  final bool statusAvailable;

  /// Modo inicial al abrir: true = estado, false = materia. El detalle toma
  /// este valor al abrirse y luego cambia de forma independiente (no afecta al
  /// toggle de la pantalla de fondo).
  final bool initialStatusMode;

  const ScheduleOverviewWidget({
    Key? key,
    required this.schedule,
    required this.onClose,
    required this.subjectColors,
    this.seatsByNrc = const {},
    this.statusAvailable = false,
    this.initialStatusMode = false,
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

  /// Modo de color propio del detalle (semi-independiente del de la pantalla):
  /// toma el valor inicial al abrir y luego cambia por su cuenta.
  late bool _statusMode;

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
    subjectColors = widget.subjectColors;
    // Toma el modo del toggle de fondo al abrir; de aquí en adelante es propio.
    _statusMode = widget.statusAvailable && widget.initialStatusMode;
  }

  /// En modo estado pero sin datos de cupos (petición fallida / Banner): no se
  /// puede colorear por estado. Se avisa en vez de pintar todo gris.
  bool get _statusUnavailable => _statusMode && widget.seatsByNrc.isEmpty;

  @override
  Widget build(BuildContext context) {
    // Usamos LayoutBuilder para detectar el tamaño y decidir el layout.
    return LayoutBuilder(
      builder: (context, constraints) {
        const double mobileBreakpoint = 600.0;
        final bool isMobileLayout = constraints.maxWidth < mobileBreakpoint;

        return Dialog(
          // Reducimos el padding para que el diálogo sea más ancho en móvil.
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobileLayout ? 16.0 : 40.0,
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          // El Dialog se ajustará al contenido.
          child: Container(
            width: isMobileLayout ? null : 1333, // Ancho flexible en móvil
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Se ajusta al contenido
              children: [
                _buildHeader(),
                // Toggle propio del detalle (semi-independiente del de fondo).
                if (widget.statusAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: isMobileLayout
                        // Móvil: pantalla angosta → leyenda (2x2) a la
                        // izquierda y el switch en vertical a la derecha
                        // (estrecho), así caben lado a lado sin desbordar.
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // La leyenda siempre ocupa su espacio (atenuada en
                              // modo materia) para que el layout no se reacomode
                              // al alternar el switch. Si el estado no se pudo
                              // obtener, se muestra un aviso en su lugar.
                              _statusUnavailable
                                  ? _buildStatusUnavailableNotice()
                                  : AnimatedOpacity(
                                      opacity: _statusMode ? 1.0 : 0.3,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child:
                                          _buildStatusLegend(twoColumns: true),
                                    ),
                              const SizedBox(width: 14),
                              ColorModeToggle(
                                vertical: true,
                                statusSelected: _statusMode,
                                statusEnabled: true,
                                onChanged: (status) =>
                                    setState(() => _statusMode = status),
                              ),
                            ],
                          )
                        // Desktop: leyenda inline a la izquierda del toggle,
                        // siempre visible (atenuada en modo materia) para no
                        // reacomodar el layout al alternar.
                        : Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _statusUnavailable
                                      ? _buildStatusUnavailableNotice()
                                      : AnimatedOpacity(
                                          opacity: _statusMode ? 1.0 : 0.3,
                                          duration: const Duration(
                                              milliseconds: 200),
                                          child: _buildStatusLegend(),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ColorModeToggle(
                                statusSelected: _statusMode,
                                statusEnabled: true,
                                onChanged: (status) =>
                                    setState(() => _statusMode = status),
                              ),
                            ],
                          ),
                  ),
                const Divider(height: 24),
                // El contenido se adapta al layout.
                Flexible(
                  child: isMobileLayout
                      ? _buildMobileContent()
                      : _buildDesktopContent(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Construye la cabecera del diálogo con el título y los botones de acción.
  Widget _buildHeader() {
    final provider = context.watch<ScheduleProvider>();
    final isFav = provider.isFavorite(widget.schedule);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Envolvemos el título en Flexible para evitar el overflow.
        const Flexible(
          child: Text(
            'Detalles del Horario',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: isFav ? 'Quitar de destacados' : 'Guardar como destacado',
              child: IconButton(
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : null,
                ),
                onPressed: () => provider.toggleFavorite(widget.schedule),
              ),
            ),
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
    );
  }

  /// Construye el layout de escritorio (dos columnas).
  Widget _buildDesktopContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildScheduleGrid(),
        ),
        const VerticalDivider(width: 24),
        Expanded(
          flex: 2,
          child: _buildDetailsList(isMobile: false),
        ),
      ],
    );
  }

  /// Construye el layout móvil (una columna).
  Widget _buildMobileContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Usamos AspectRatio para que la tabla sea más ancha que alta.
          AspectRatio(
            aspectRatio: 0.85, // Alto más grande que ancho
            child: _buildScheduleGrid(),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: _buildDetailsList(isMobile: true),
          ),
        ],
      ),
    );
  }

  /// Construye la lista de detalles de las materias.
  Widget _buildDetailsList({bool isMobile = false}) {
    //
    final Map<String, List<ClassOption>> groupedSubjects =
        groupBy(widget.schedule, (ClassOption option) => option.subjectName);

    return ListView.builder(
      shrinkWrap: isMobile,
      physics: isMobile ? const NeverScrollableScrollPhysics() : null,
      itemCount: groupedSubjects.length,
      itemBuilder: (context, index) {
        final subjectName = groupedSubjects.keys.elementAt(index);
        final classOptions = groupedSubjects[subjectName]!;
        final color = subjectColors[subjectName] ?? Colors.grey;

        return ExpansionTile(
          leading: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  subjectName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (classOptions.any(_optionUnavailable)) ...[
                const SizedBox(width: 10),
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 24),
              ],
            ],
          ),
          // Muestra los detalles de la clase (NRC, profesor, etc.) al expandir.
          children: classOptions.map((option) {
            return ListTile(
              contentPadding:
                  const EdgeInsets.only(left: 40, right: 16, bottom: 8),
              tileColor:
                  _optionUnavailable(option) ? Colors.red.shade100 : null,
              title: Text(
                '${option.type} (NRC: ${option.nrc})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Profesor: ${option.professor}\n'
                'Horario: ${formattingSchedulesInPairs(option.schedules)}\n'
                'Campus: ${option.campus}\n'
                '${_cuposLabel(option)}\n'
                'Créditos: ${option.credits}',
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Etiqueta de cupos: en vivo (desde `/status`) si hay datos cargados; si no,
  /// el snapshot guardado con el favorito.
  String _cuposLabel(ClassOption option) {
    final live = widget.seatsByNrc[option.nrc];
    if (live != null) {
      return 'Cupos: ${live['available']} de ${live['total']} (actuales)';
    }
    // Favorito del término actual sin dato en vivo para este NRC: el curso ya
    // no está en la oferta, o no se pudo consultar. En ambos casos no se
    // muestra el snapshot viejo como si fuera actual.
    if (widget.statusAvailable) return 'Cupos: no disponible';
    // Generación o término pasado: se muestra el valor tal cual.
    return 'Cupos: ${option.seatsAvailable} de ${option.seatsMaximum}';
  }

  /// Si la opción no tiene cupos / ya no se ofrece. Usa datos en vivo cuando
  /// existen; si no, el snapshot. Si no se pudo consultar (mapa vacío en
  /// término actual) no se marca en rojo: no se sabe.
  bool _optionUnavailable(ClassOption option) {
    final live = widget.seatsByNrc[option.nrc];
    if (live != null) return (live['available'] ?? 0) <= 0;
    // Datos cargados pero este NRC ausente => eliminado de la oferta.
    if (widget.statusAvailable && widget.seatsByNrc.isNotEmpty) return true;
    // Mapa vacío (no se pudo consultar): no alarmar en rojo.
    if (widget.statusAvailable) return false;
    return option.seatsAvailable == 0; // generación / término pasado
  }

  /// Aviso cuando "Estado" está activo pero no se pudieron obtener los cupos
  /// (en vez de pintar la grilla toda gris, que parecería "todo eliminado").
  Widget _buildStatusUnavailableNotice() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.cloud_off, size: 15, color: Color(0xFFB45309)),
        SizedBox(width: 6),
        Text('Estado no disponible',
            style: TextStyle(
                fontSize: 12,
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  /// Leyenda compacta de colores de estado (la "paleta"), para explicar el
  /// coloreo de la grilla cuando el detalle está en modo estado.
  ///
  /// En [twoColumns] (móvil) se muestra como dos filas de dos, en vez de una
  /// sola fila que en pantallas angostas requeriría scroll horizontal.
  Widget _buildStatusLegend({bool twoColumns = false}) {
    // `flexible` permite que la etiqueta se recorte con ellipsis cuando el
    // ancho es limitado (modo dos columnas, dentro de un Expanded).
    Widget item(CourseStatus status, {bool flexible = false}) {
      final label = Text(courseStatusLabel(status),
          overflow: flexible ? TextOverflow.ellipsis : TextOverflow.clip,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)));
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: courseStatusColor(status),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          flexible ? Flexible(child: label) : label,
        ],
      );
    }

    if (twoColumns) {
      // Dos filas de dos, compacto y pegado a la izquierda. La primera columna
      // tiene un ancho fijo ajustado para que la segunda quede cerca (no
      // repartida a lo ancho).
      Widget row(CourseStatus a, CourseStatus b) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 80, child: item(a)),
              item(b),
            ],
          );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(CourseStatus.safe, CourseStatus.caution),
          const SizedBox(height: 6),
          row(CourseStatus.atRisk, CourseStatus.eliminated),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        item(CourseStatus.safe),
        const SizedBox(width: 12),
        item(CourseStatus.caution),
        const SizedBox(width: 12),
        item(CourseStatus.atRisk),
        const SizedBox(width: 12),
        item(CourseStatus.eliminated),
      ],
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
      final endHour = timeRange.end.hour + (timeRange.end.minute + 10) / 60.0;

      final top = (startHour - 7) * hourRowHeight;
      final height = (endHour - startHour) * hourRowHeight;
      final left = dayIndex * dayColumnWidth;

      if (top >= 0 && height > 0) {
        // Color del bloque: por estado de cupos (modo estado, solo si hay
        // datos) o por materia. Sin datos en modo estado → materia (no gris).
        final Color color = (_statusMode && widget.seatsByNrc.isNotEmpty)
            ? courseStatusColor(
                statusForClass(overlappingClasses.first, widget.seatsByNrc))
            : (subjectColors[overlappingClasses.first.subjectName] ??
                Colors.grey);

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
    sheetObject.appendRow(
        ['Horario', ...days].map((day) => excel.TextCellValue(day)).toList());

    // Llena cada fila con la materia correspondiente a la hora y día.
    for (var timeSlot in timeSlots) {
      List<excel.CellValue?> row = [excel.TextCellValue(timeSlot)];
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
          row.add(excel.TextCellValue(
              '${classOption.subjectName}\nNRC: ${classOption.nrc}'));
        } else {
          row.add(null); // Añade una celda vacía
        }
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
