// lib/services/schedule_export.dart
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/class_option.dart';
import '../utils/credit_utils.dart';
import '../utils/time_utils.dart';

/// Exportación de un horario a PDF y Excel.
///
/// Ambos formatos reproducen la grilla semanal de la app (bloques coloreados
/// por materia, del alto de su duración) y añaden una tabla con el detalle de
/// cada clase. Solo se dibujan los días y las horas que el horario usa, para no
/// exportar una rejilla medio vacía.

const List<String> _weekDays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Días que siempre se muestran, aunque no tengan clases: un horario sin clases
/// el martes se sigue leyendo mejor con la columna vacía que sin ella.
const int _minDays = 5; // Lunes a Viernes

/// Un bloque de la grilla: una franja de un día, con las clases que caen en ella
/// (más de una si se solapan).
class _Block {
  final String day;
  final double start; // Hora decimal (8.5 == 08:30).
  final double end;
  final List<ClassOption> options;

  _Block(this.day, this.start, this.end, this.options);

  ClassOption get first => options.first;
}

/// Geometría del horario: qué días y qué franja horaria hay que dibujar.
class _Layout {
  final List<String> days;
  final int startHour;
  final int endHour;
  final List<_Block> blocks;

  _Layout(this.days, this.startHour, this.endHour, this.blocks);

  int get hourCount => endHour - startHour;
  List<int> get hours => List.generate(hourCount, (i) => startHour + i);
}

_Layout _buildLayout(List<ClassOption> schedule) {
  // Agrupa por día+franja para que dos clases solapadas compartan un bloque, en
  // vez de que una tape a la otra.
  final Map<String, List<ClassOption>> byDayAndTime = {};
  for (final option in schedule) {
    for (final s in option.schedules) {
      byDayAndTime.putIfAbsent('${s.day}_${s.time}', () => []).add(option);
    }
  }

  final List<_Block> blocks = [];
  for (final entry in byDayAndTime.entries) {
    final parts = entry.key.split('_');
    final day = parts[0];
    if (!_weekDays.contains(day)) continue;

    final range = TimeUtils.parseTimeRange(parts[1]);
    final start = range.start.hour + range.start.minute / 60.0;
    final end = range.end.hour + range.end.minute / 60.0;
    if (end <= start) continue;

    blocks.add(_Block(day, start, end, entry.value));
  }

  // Rango horario fijo 07:00–20:00, igual que la grilla de la app (endHour es
  // exclusivo: la última fila visible es 20:00). Solo se amplía hacia afuera si
  // el horario tiene alguna clase antes de las 7 o después de las 20, para no
  // recortarla nunca.
  int startHour = 7;
  int endHour = 21;
  for (final b in blocks) {
    final blockStart = b.start.floor();
    final blockEnd = b.end.ceil();
    if (blockStart < startHour) startHour = blockStart;
    if (blockEnd > endHour) endHour = blockEnd;
  }
  startHour = startHour.clamp(6, 20);
  endHour = endHour.clamp(startHour + 1, 24);

  // Lunes a Viernes siempre; sábado y domingo solo si tienen clase.
  final usedDays = blocks.map((b) => b.day).toSet();
  final days = _weekDays
      .whereIndexed((i, day) => i < _minDays || usedDays.contains(day))
      .toList();

  return _Layout(days, startHour, endHour, blocks);
}

/// Materias del horario (una entrada por materia, no por clase) en el orden en
/// que aparecen. Es el orden que usan la leyenda y la tabla de detalle.
///
/// La llave es `subjectKey` (código+nombre), no el nombre: dos materias
/// distintas que se llaman igual son dos entradas. Agrupar por nombre las
/// fusionaba en una, lo que además hacía que `_totalCredits` contara los
/// créditos de una sola. Ojo: la llave **no** es texto para mostrar; para eso
/// va `entry.value.first.subjectName`.
Map<String, List<ClassOption>> _subjectsOf(List<ClassOption> schedule) =>
    groupBy(schedule, (ClassOption o) => o.subjectKey);

/// Créditos totales del horario: se cuentan una vez por materia (el teórico y su
/// laboratorio comparten los créditos de la materia, no se suman dos veces).
double _totalCredits(List<ClassOption> schedule) => roundCredits(
    _subjectsOf(schedule).values.map((o) => o.first.credits).fold(0.0, (a, b) => a + b));

/// Color de fondo de un bloque: el color de la materia aclarado, para que el
/// texto se lea en negro y no gaste tinta al imprimir. La opacidad marca cuánto
/// del color de la materia se ve; se mantiene por debajo de ~0.4 para que el
/// texto negro encima siga legible.
Color _tint(Color color) => Color.alphaBlend(color.withOpacity(0.36), Colors.white);

String _hex(Color color) =>
    '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

String _hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

/// "07:00 - 08:50" de un bloque.
String _blockRange(_Block block) {
  String fmt(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  return '${fmt(block.start)} - ${fmt(block.end)}';
}

String _todayLabel() {
  final now = DateTime.now();
  final d = now.day.toString().padLeft(2, '0');
  final m = now.month.toString().padLeft(2, '0');
  return '$d/$m/${now.year}';
}

/// Resumen del horario para las cabeceras: "6 materias · 18 créditos".
String _summary(List<ClassOption> schedule) {
  final subjects = _subjectsOf(schedule).length;
  final credits = formatCredits(_totalCredits(schedule));
  final plural = subjects == 1 ? 'materia' : 'materias';
  return '$subjects $plural · $credits créditos';
}

// ===========================================================================
// PDF
// ===========================================================================

/// Paleta del documento (neutros del PDF; los bloques usan el color de materia).
const PdfColor _pdfInk = PdfColor.fromInt(0xFF1F2937);
const PdfColor _pdfMuted = PdfColor.fromInt(0xFF6B7280);
const PdfColor _pdfLine = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _pdfSoftLine = PdfColor.fromInt(0xFFE5E7EB);
const PdfColor _pdfHeaderBg = PdfColor.fromInt(0xFF093AD8); // AppColors.primary
const PdfColor _pdfZebra = PdfColor.fromInt(0xFFF3F4F6);

PdfColor _pdf(Color color) => PdfColor.fromInt(color.value);

/// Genera el PDF del horario: cabecera, grilla semanal y tabla de detalle.
Future<Uint8List> buildSchedulePdf({
  required List<ClassOption> schedule,
  required Map<String, Color> subjectColors,
}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  // El bold da jerarquía a títulos y encabezados, pero no es imprescindible: si
  // el asset no está empaquetado (ej. build web sin rebuild tras añadirlo), se
  // degrada a la regular en vez de tumbar toda la generación del PDF.
  pw.Font bold;
  try {
    bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  } catch (_) {
    bold = regular;
  }

  final layout = _buildLayout(schedule);
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold).copyWith(
      defaultTextStyle: pw.TextStyle(font: regular, fontSize: 9, color: _pdfInk),
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 24),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Generador de Horarios UTB · horario.lab.utb.edu.co   ·   '
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 7, color: _pdfMuted),
        ),
      ),
      build: (context) => [
        _pdfHeader(schedule),
        pw.SizedBox(height: 10),
        _pdfLegend(schedule, subjectColors),
        pw.SizedBox(height: 12),
        _pdfGrid(layout, subjectColors),
        // El detalle empieza en su propia página para que el título "Detalle de
        // clases" no quede huérfano al final de la grilla (que ocupa casi toda
        // la primera página).
        pw.NewPage(),
        _pdfDetails(schedule, subjectColors),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _pdfHeader(List<ClassOption> schedule) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Horario Académico',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(_summary(schedule),
              style: pw.TextStyle(fontSize: 10, color: _pdfMuted)),
        ],
      ),
      pw.Text('Generado el ${_todayLabel()}',
          style: pw.TextStyle(fontSize: 8, color: _pdfMuted)),
    ],
  );
}

/// Leyenda de colores: un chip por materia (cuadro con el color de la materia +
/// nombre y créditos). Cada chip replica el estilo de los bloques de la grilla
/// —fondo aclarado con barra de color a la izquierda— para que el color se
/// reconozca de un vistazo entre la leyenda, la grilla y la tabla de detalle.
pw.Widget _pdfLegend(
    List<ClassOption> schedule, Map<String, Color> subjectColors) {
  final chips = _subjectsOf(schedule).entries.map((entry) {
    final color = subjectColors[entry.key] ?? Colors.grey;
    final credits = formatCredits(entry.value.first.credits);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: _pdf(_tint(color)),
        border: pw.Border(left: pw.BorderSide(color: _pdf(color), width: 3)),
      ),
      child: pw.Text('${entry.value.first.subjectName}  ·  $credits cr.',
          style: pw.TextStyle(fontSize: 7.5, color: _pdfInk)),
    );
  }).toList();

  return pw.Wrap(spacing: 8, runSpacing: 6, children: chips);
}

/// Grilla semanal. Se dibuja con un Stack: al fondo la rejilla de horas y días,
/// encima cada bloque posicionado según su hora de inicio y su duración (igual
/// que en la app), en vez de repetir el nombre de la materia en cada fila.
pw.Widget _pdfGrid(_Layout layout, Map<String, Color> subjectColors) {
  const double hourColumnWidth = 42;
  const double headerHeight = 20;
  const double rowHeight = 26;
  // Ancho útil de una A4 apaisada con los márgenes de la página.
  final double gridWidth = PdfPageFormat.a4.height - 56;
  final double dayWidth = (gridWidth - hourColumnWidth) / layout.days.length;
  final double bodyHeight = rowHeight * layout.hourCount;

  pw.Widget dayHeader(String day) => pw.Container(
        width: dayWidth,
        height: headerHeight,
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(
          color: _pdfHeaderBg,
          border: pw.Border(left: pw.BorderSide(color: PdfColors.white, width: 0.5)),
        ),
        child: pw.Text(day,
            style: pw.TextStyle(
                fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      );

  // Fondo: una fila por hora.
  final rows = layout.hours.map((hour) {
    return pw.Container(
      height: rowHeight,
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _pdfSoftLine, width: 0.5)),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: hourColumnWidth,
            height: rowHeight,
            alignment: pw.Alignment.topCenter,
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(_hourLabel(hour),
                style: pw.TextStyle(fontSize: 7, color: _pdfMuted)),
          ),
          ...layout.days.map((_) => pw.Container(
                width: dayWidth,
                height: rowHeight,
                decoration: const pw.BoxDecoration(
                  border:
                      pw.Border(left: pw.BorderSide(color: _pdfSoftLine, width: 0.5)),
                ),
              )),
        ],
      ),
    );
  }).toList();

  // Bloques de clase, posicionados sobre la rejilla.
  final blocks = layout.blocks.map((block) {
    final dayIndex = layout.days.indexOf(block.day);
    if (dayIndex == -1) return pw.SizedBox();

    final color = subjectColors[block.first.subjectKey] ?? Colors.grey;
    final top = (block.start - layout.startHour) * rowHeight;
    final height = (block.end - block.start) * rowHeight;
    final nrcs = block.options.map((o) => o.nrc).join(' / ');
    final types = block.options.map((o) => o.type).toSet().join(' / ');

    return pw.Positioned(
      top: top,
      left: hourColumnWidth + dayIndex * dayWidth,
      child: pw.Container(
        width: dayWidth - 2,
        height: height - 2,
        margin: const pw.EdgeInsets.all(1),
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: pw.BoxDecoration(
          color: _pdf(_tint(color)),
          // Barra de color de la materia a la izquierda. Sin borderRadius: el
          // paquete pdf solo lo admite con bordes uniformes.
          border: pw.Border(left: pw.BorderSide(color: _pdf(color), width: 2.5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              block.first.subjectName,
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('$types · NRC $nrcs',
                maxLines: 1, style: pw.TextStyle(fontSize: 5.5, color: _pdfInk)),
            pw.Text(_blockRange(block),
                maxLines: 1, style: pw.TextStyle(fontSize: 5.5, color: _pdfInk)),
          ],
        ),
      ),
    );
  }).toList();

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _pdfLine, width: 0.5),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Column(
      children: [
        pw.Row(children: [
          pw.Container(
              width: hourColumnWidth, height: headerHeight, color: _pdfHeaderBg),
          ...layout.days.map(dayHeader),
        ]),
        pw.SizedBox(
          height: bodyHeight,
          width: gridWidth,
          child: pw.Stack(children: [
            pw.Column(children: rows),
            ...blocks,
          ]),
        ),
      ],
    ),
  );
}

/// Tabla de detalle: una fila por clase, con el color de la materia como guía.
pw.Widget _pdfDetails(List<ClassOption> schedule, Map<String, Color> subjectColors) {
  const headers = [
    'Materia',
    'Tipo',
    'NRC',
    'Profesor',
    'Campus',
    'Créditos',
    'Horario',
  ];
  const widths = {
    0: pw.FlexColumnWidth(2.6),
    1: pw.FlexColumnWidth(1.1),
    2: pw.FlexColumnWidth(0.8),
    3: pw.FlexColumnWidth(2.4),
    4: pw.FlexColumnWidth(1.4),
    5: pw.FlexColumnWidth(0.8),
    6: pw.FlexColumnWidth(2.6),
  };

  pw.Widget cell(String text, {bool bold = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(text,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? _pdfInk,
            )),
      );

  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _pdfHeaderBg),
      children: headers
          .map((h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: pw.Text(h,
                    style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ))
          .toList(),
    ),
  ];

  // Agrupadas por materia para que teórico y laboratorio salgan juntos.
  var index = 0;
  for (final entry in _subjectsOf(schedule).entries) {
    final color = subjectColors[entry.key] ?? Colors.grey;
    for (final option in entry.value) {
      final horario = option.schedules
          .map((s) => '${s.day} ${s.time}')
          .join('\n');

      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(
          color: index.isEven ? PdfColors.white : _pdfZebra,
          border: pw.Border(left: pw.BorderSide(color: _pdf(color), width: 3)),
        ),
        children: [
          cell(option.subjectName, bold: true),
          cell(option.type),
          cell(option.nrc),
          cell(option.professor),
          cell(option.campus),
          cell(formatCredits(option.credits)),
          cell(horario, color: _pdfMuted),
        ],
      ));
      index++;
    }
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Detalle de clases',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Table(
        columnWidths: widths,
        border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: _pdfSoftLine, width: 0.5),
        ),
        children: rows,
      ),
    ],
  );
}

// ===========================================================================
// Excel
// ===========================================================================

const String _xlHeaderBg = '#093AD8';
const String _xlHourBg = '#F3F4F6';
const String _xlBorderColor = '#D1D5DB';

/// Genera el .xlsx del horario: hoja "Horario" con la grilla (bloques fusionados
/// del alto de su duración) y hoja "Detalle" con una clase por fila.
Future<Uint8List> buildScheduleExcel({
  required List<ClassOption> schedule,
  required Map<String, Color> subjectColors,
}) async {
  final layout = _buildLayout(schedule);
  final book = xls.Excel.createExcel();

  _excelGridSheet(book, schedule, layout, subjectColors);
  _excelDetailsSheet(book, schedule);

  // createExcel() deja una hoja vacía por defecto.
  book.delete('Sheet1');
  book.setDefaultSheet('Horario');

  final bytes = book.encode();
  return Uint8List.fromList(bytes!);
}

xls.CellIndex _at(int column, int row) =>
    xls.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row);

void _excelGridSheet(
  xls.Excel book,
  List<ClassOption> schedule,
  _Layout layout,
  Map<String, Color> subjectColors,
) {
  final sheet = book['Horario'];

  // Título y resumen, fusionados a lo ancho de la tabla.
  final lastColumn = layout.days.length;
  sheet.updateCell(_at(0, 0), xls.TextCellValue('Horario Académico'),
      cellStyle: xls.CellStyle(bold: true, fontSize: 16));
  sheet.merge(_at(0, 0), _at(lastColumn, 0));

  sheet.updateCell(
      _at(0, 1),
      xls.TextCellValue('${_summary(schedule)} · Generado el ${_todayLabel()}'),
      cellStyle: xls.CellStyle(
          fontSize: 10, fontColorHex: xls.ExcelColor.fromHexString('#6B7280')));
  sheet.merge(_at(0, 1), _at(lastColumn, 1));

  // Encabezado de la grilla (fila 3, dejando la 2 en blanco).
  const headerRow = 3;
  final headerStyle = xls.CellStyle(
    bold: true,
    fontSize: 11,
    fontColorHex: xls.ExcelColor.white,
    backgroundColorHex: xls.ExcelColor.fromHexString(_xlHeaderBg),
    horizontalAlign: xls.HorizontalAlign.Center,
    verticalAlign: xls.VerticalAlign.Center,
  );

  sheet.updateCell(_at(0, headerRow), xls.TextCellValue('Hora'),
      cellStyle: headerStyle);
  layout.days.forEachIndexed((i, day) {
    sheet.updateCell(_at(i + 1, headerRow), xls.TextCellValue(day),
        cellStyle: headerStyle);
  });

  // Columna de horas.
  final hourStyle = xls.CellStyle(
    bold: true,
    fontSize: 10,
    backgroundColorHex: xls.ExcelColor.fromHexString(_xlHourBg),
    horizontalAlign: xls.HorizontalAlign.Center,
    verticalAlign: xls.VerticalAlign.Center,
    leftBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
  );

  final emptyStyle = xls.CellStyle(
    leftBorder: xls.Border(
        borderStyle: xls.BorderStyle.Thin,
        borderColorHex: xls.ExcelColor.fromHexString(_xlBorderColor)),
    rightBorder: xls.Border(
        borderStyle: xls.BorderStyle.Thin,
        borderColorHex: xls.ExcelColor.fromHexString(_xlBorderColor)),
    topBorder: xls.Border(
        borderStyle: xls.BorderStyle.Thin,
        borderColorHex: xls.ExcelColor.fromHexString(_xlBorderColor)),
    bottomBorder: xls.Border(
        borderStyle: xls.BorderStyle.Thin,
        borderColorHex: xls.ExcelColor.fromHexString(_xlBorderColor)),
  );

  for (var i = 0; i < layout.hourCount; i++) {
    final row = headerRow + 1 + i;
    final hour = layout.startHour + i;
    sheet.updateCell(
        _at(0, row), xls.TextCellValue('${_hourLabel(hour)} - ${_hourLabel(hour + 1)}'),
        cellStyle: hourStyle);
    sheet.setRowHeight(row, 34);

    // Celdas vacías: se pintan con borde para que la rejilla se vea completa.
    for (var c = 1; c <= layout.days.length; c++) {
      sheet.updateCell(_at(c, row), xls.TextCellValue(''), cellStyle: emptyStyle);
    }
  }

  // Bloques de clase: una celda fusionada que cubre las horas que ocupa.
  for (final block in layout.blocks) {
    final dayIndex = layout.days.indexOf(block.day);
    if (dayIndex == -1) continue;

    final startRow = headerRow + 1 + (block.start.floor() - layout.startHour);
    // La hora de fin (ej. 08:50) ocupa su propia fila; 09:00 exacto, no.
    final endRow = headerRow + (block.end.ceil() - layout.startHour);
    if (startRow < headerRow + 1 || endRow < startRow) continue;

    final color = subjectColors[block.first.subjectKey] ?? Colors.grey;
    final nrcs = block.options.map((o) => o.nrc).join(' / ');
    final types = block.options.map((o) => o.type).toSet().join(' / ');
    final text = '${block.first.subjectName}\n'
        '$types · NRC $nrcs\n'
        '${_blockRange(block)}';

    final style = xls.CellStyle(
      fontSize: 9,
      backgroundColorHex: xls.ExcelColor.fromHexString(_hex(_tint(color))),
      horizontalAlign: xls.HorizontalAlign.Center,
      verticalAlign: xls.VerticalAlign.Center,
      textWrapping: xls.TextWrapping.WrapText,
      leftBorder: xls.Border(
          borderStyle: xls.BorderStyle.Medium,
          borderColorHex: xls.ExcelColor.fromHexString(_hex(color))),
      rightBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      topBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
      bottomBorder: xls.Border(borderStyle: xls.BorderStyle.Thin),
    );

    // Primero se fusiona y después se escribe: merge() descarta el contenido y
    // el estilo previos de las celdas del rango, mientras que updateCell()
    // reconoce la fusión y escribe en la celda ancla (que da color a todo el
    // bloque fusionado).
    final cell = _at(dayIndex + 1, startRow);
    if (endRow > startRow) {
      sheet.merge(cell, _at(dayIndex + 1, endRow));
    }
    sheet.updateCell(cell, xls.TextCellValue(text), cellStyle: style);
  }

  sheet.setColumnWidth(0, 14);
  for (var c = 1; c <= layout.days.length; c++) {
    sheet.setColumnWidth(c, 26);
  }
}

void _excelDetailsSheet(xls.Excel book, List<ClassOption> schedule) {
  final sheet = book['Detalle'];

  const headers = [
    'Materia',
    'Tipo',
    'NRC',
    'Profesor',
    'Campus',
    'Créditos',
    'Cupos',
    'Horario',
  ];
  final headerStyle = xls.CellStyle(
    bold: true,
    fontColorHex: xls.ExcelColor.white,
    backgroundColorHex: xls.ExcelColor.fromHexString(_xlHeaderBg),
    horizontalAlign: xls.HorizontalAlign.Center,
  );

  headers.forEachIndexed((i, h) {
    sheet.updateCell(_at(i, 0), xls.TextCellValue(h), cellStyle: headerStyle);
  });

  final bodyStyle = xls.CellStyle(verticalAlign: xls.VerticalAlign.Center);
  var row = 1;
  for (final entry in _subjectsOf(schedule).entries) {
    for (final option in entry.value) {
      final values = <xls.CellValue>[
        xls.TextCellValue(option.subjectName),
        xls.TextCellValue(option.type),
        xls.TextCellValue(option.nrc),
        xls.TextCellValue(option.professor),
        xls.TextCellValue(option.campus),
        xls.TextCellValue(formatCredits(option.credits)),
        xls.TextCellValue('${option.seatsAvailable} de ${option.seatsMaximum}'),
        xls.TextCellValue(
            option.schedules.map((s) => '${s.day} ${s.time}').join(' | ')),
      ];
      values.forEachIndexed((i, v) {
        sheet.updateCell(_at(i, row), v, cellStyle: bodyStyle);
      });
      row++;
    }
  }

  // Fila de total de créditos.
  sheet.updateCell(_at(4, row + 1), xls.TextCellValue('Total créditos'),
      cellStyle: xls.CellStyle(bold: true, horizontalAlign: xls.HorizontalAlign.Right));
  sheet.updateCell(
      _at(5, row + 1), xls.TextCellValue(formatCredits(_totalCredits(schedule))),
      cellStyle: xls.CellStyle(bold: true));

  const widths = [34.0, 14.0, 10.0, 30.0, 22.0, 10.0, 12.0, 46.0];
  widths.forEachIndexed((i, w) => sheet.setColumnWidth(i, w));
}
