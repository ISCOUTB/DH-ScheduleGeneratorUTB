// test/schedule_export_test.dart
import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dh_schedule_generatorutb/models/class_option.dart';
import 'package:dh_schedule_generatorutb/models/schedule.dart';
import 'package:dh_schedule_generatorutb/services/schedule_export.dart';

/// Genera los dos archivos de exportación con un horario de muestra y comprueba
/// que salen bien formados. Los deja escritos en un directorio temporal, que se
/// imprime al correr el test, para poder abrirlos y revisarlos a ojo.

ClassOption _option({
  required String subject,
  required String type,
  required String nrc,
  required double credits,
  required List<List<String>> slots, // [[día, "07:00 - 08:50"], ...]
  String professor = 'Docente De Prueba',
}) {
  return ClassOption(
    subjectName: subject,
    subjectCode: 'COD${nrc.substring(0, 2)}',
    type: type,
    professor: professor,
    nrc: nrc,
    groupId: 1,
    credits: credits,
    campus: 'Campus Tecnológico',
    seatsAvailable: 12,
    seatsMaximum: 30,
    schedules: slots.map((s) => Schedule(day: s[0], time: s[1])).toList(),
  );
}

void main() {
  // El PDF carga sus fuentes con rootBundle, que necesita el binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  final schedule = <ClassOption>[
    _option(
      subject: 'Física Calor Y Ondas',
      type: 'Teórico',
      nrc: '1001',
      credits: 4,
      slots: [
        ['Miércoles', '13:00 - 14:50'],
        ['Viernes', '14:00 - 15:50'],
      ],
    ),
    _option(
      subject: 'Física Calor Y Ondas',
      type: 'Laboratorio',
      nrc: '1002',
      credits: 4,
      slots: [
        ['Lunes', '09:00 - 10:50'],
      ],
    ),
    _option(
      subject: 'Programación Orientada A Objetos',
      type: 'Teórico',
      nrc: '2221',
      credits: 3,
      professor: 'Carlos Ernesto Botero Pareja',
      slots: [
        ['Martes', '07:00 - 08:50'],
        ['Jueves', '16:00 - 16:50'],
      ],
    ),
    _option(
      subject: 'Seminario De Desarrollo Personal I',
      type: 'Teórico',
      nrc: '1500',
      credits: 0.5, // Materia de medio crédito.
      slots: [
        ['Sábado', '08:00 - 09:50'],
      ],
    ),
  ];

  final colors = <String, Color>{
    'Física Calor Y Ondas': const Color(0xFF2979FF),
    'Programación Orientada A Objetos': const Color(0xFF1ABC7B),
    'Seminario De Desarrollo Personal I': const Color(0xFFE67E22),
  };

  late Directory outDir;

  setUpAll(() {
    outDir = Directory.systemTemp.createTempSync('horario_export_');
    debugPrint('Archivos de exportación en: ${outDir.path}');
  });

  test('el PDF se genera y es un PDF válido', () async {
    final bytes = await buildSchedulePdf(schedule: schedule, subjectColors: colors);

    // Cabecera mágica de un PDF.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(10000)); // Fuentes incrustadas + contenido.

    File('${outDir.path}/Horario_UTB.pdf').writeAsBytesSync(bytes);
  });

  test('el Excel se genera y es un xlsx válido', () async {
    final bytes = await buildScheduleExcel(schedule: schedule, subjectColors: colors);

    // Un .xlsx es un ZIP: empieza por "PK".
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4B);
    expect(bytes.length, greaterThan(2000));

    File('${outDir.path}/Horario_UTB.xlsx').writeAsBytesSync(bytes);
  });

  test('los bloques fusionados de la grilla conservan su texto', () async {
    // merge() descarta el contenido de las celdas del rango, así que un orden
    // equivocado deja los bloques de varias horas en blanco.
    final book = xls.Excel.decodeBytes(
      await buildScheduleExcel(schedule: schedule, subjectColors: colors),
    );

    expect(book.sheets.keys, containsAll(['Horario', 'Detalle']));

    final grid = book['Horario'];
    expect(grid.spannedItems, isNotEmpty, reason: 'debe haber celdas fusionadas');

    final texts = grid.rows
        .expand((row) => row)
        .map((cell) => cell?.value?.toString() ?? '')
        .toList();

    // Física (09:00-10:50) abarca dos filas: es una celda fusionada.
    expect(texts.any((t) => t.contains('Física Calor Y Ondas')), isTrue);
    expect(texts.any((t) => t.contains('NRC 1002')), isTrue);
  });

  test('la grilla mantiene el rango fijo 07:00–20:00', () async {
    // Un horario solo por la tarde no debe recortar las horas de la mañana: la
    // grilla exportada conserva el rango completo, como en la app.
    final soloTarde = <ClassOption>[
      _option(
        subject: 'Administración De La Cadena De Valor',
        type: 'Teórico',
        nrc: '2251',
        credits: 3,
        slots: [
          ['Jueves', '17:00 - 18:50'],
        ],
      ),
    ];

    final book = xls.Excel.decodeBytes(
      await buildScheduleExcel(schedule: soloTarde, subjectColors: colors),
    );
    final texts = book['Horario']
        .rows
        .expand((row) => row)
        .map((cell) => cell?.value?.toString() ?? '')
        .toList();

    // Primera y última franja del rango fijo presentes, aunque la única clase
    // sea a las 17:00.
    expect(texts.any((t) => t.startsWith('07:00')), isTrue);
    expect(texts.any((t) => t.startsWith('20:00')), isTrue);
  });

  test('un horario vacío no revienta la exportación', () async {
    final pdf = await buildSchedulePdf(schedule: [], subjectColors: {});
    final xlsx = await buildScheduleExcel(schedule: [], subjectColors: {});

    expect(pdf.length, greaterThan(0));
    expect(xlsx.length, greaterThan(0));
  });
}
