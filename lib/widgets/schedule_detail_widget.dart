// lib/widgets/schedule_detail_widget.dart
import 'package:flutter/material.dart';
import 'dart:async';

class ScheduleDetailWidget extends StatefulWidget {
  final List<Map<String, List<String>>> schedule;
  final VoidCallback onClose;

  const ScheduleDetailWidget({
    Key? key,
    required this.schedule,
    required this.onClose,
  }) : super(key: key);

  @override
  _ScheduleDetailWidgetState createState() => _ScheduleDetailWidgetState();
}

class _ScheduleDetailWidgetState extends State<ScheduleDetailWidget> {
  String? hoveredSubject;
  Timer? hideTimer;

  // Simulated subject details
  final Map<String, Map<String, String>> subjectDetails = {
    'Matemáticas': {'Profesor': 'Dr. García', 'NRC': '12345'},
    'Física': {'Profesor': 'Ing. Pérez', 'NRC': '23456'},
    'Química': {'Profesor': 'Dra. López', 'NRC': '34567'},
    'Programación': {'Profesor': 'Lic. Sánchez', 'NRC': '45678'},
    'Historia': {'Profesor': 'Prof. Martínez', 'NRC': '56789'},
    'Estadística': {'Profesor': 'Msc. Rodríguez', 'NRC': '67890'},
    'Biología': {'Profesor': 'Dr. Fernández', 'NRC': '78901'},
    'Literatura': {'Profesor': 'Lic. Gómez', 'NRC': '89012'},
    'Filosofía': {'Profesor': 'Prof. Díaz', 'NRC': '90123'},
    'Música': {'Profesor': 'Mtro. Hernández', 'NRC': '01234'},
    // Add more subjects as needed
  };

  @override
  void dispose() {
    hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Define time slots and days
    final List<String> timeSlots = [
      '08:00 - 09:00',
      '09:00 - 10:00',
      '10:00 - 11:00',
      '11:00 - 12:00',
      '12:00 - 13:00',
      '13:00 - 14:00',
      '14:00 - 15:00',
      '15:00 - 16:00',
      '16:00 - 17:00',
      '17:00 - 18:00',
      '18:00 - 19:00',
      '19:00 - 20:00',
    ];

    final List<String> days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado'
    ];

    // Create the schedule matrix
    Map<String, Map<String, String>> scheduleMatrix = {};

    for (String time in timeSlots) {
      scheduleMatrix[time] = {};
      for (String day in days) {
        scheduleMatrix[time]![day] = ''; // Initially empty
      }
    }

    // Fill the schedule matrix with subjects
    for (var daySchedule in widget.schedule) {
      String day = daySchedule.keys.first;
      List<String> subjects = daySchedule.values.first;

      for (String subjectInfo in subjects) {
        if (subjectInfo.contains('(') && subjectInfo.contains(')')) {
          String subjectName =
              subjectInfo.substring(0, subjectInfo.indexOf('(')).trim();
          String time = subjectInfo.substring(
              subjectInfo.indexOf('(') + 1, subjectInfo.indexOf(')')).trim();

          if (scheduleMatrix.containsKey(time)) {
            scheduleMatrix[time]![day] = subjectName;
          }
        }
      }
    }

    // Get the list of subjects
    Set<String> subjectsSet = {};
    for (var day in days) {
      for (var time in timeSlots) {
        String subjectName = scheduleMatrix[time]![day]!;
        if (subjectName.isNotEmpty) {
          subjectsSet.add(subjectName);
        }
      }
    }

    List<String> subjectsList = subjectsSet.toList();

    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Download and close buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () {
                    // Implement logic to download as PDF
                  },
                  tooltip: 'Descargar como PDF',
                ),
                IconButton(
                  icon: const Icon(Icons.table_chart),
                  onPressed: () {
                    // Implement logic to download as spreadsheet
                  },
                  tooltip: 'Descargar como Hoja de Cálculo',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            // Display the full schedule
            Expanded(
              child: SingleChildScrollView(
                child: Table(
                  border: TableBorder.all(color: Colors.grey),
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  children: [
                    // Header row (days)
                    TableRow(
                      children: [
                        Container(), // Empty cell in the top-left corner
                        ...days.map((day) => Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                day,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            )),
                      ],
                    ),
                    // Time slot rows
                    ...timeSlots.map((time) {
                      return TableRow(
                        children: [
                          // Time column
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              time,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          // Subject cells
                          ...days.map((day) {
                            String subjectName = scheduleMatrix[time]![day] ?? '';
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                subjectName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // List of subjects with info icon
            SizedBox(
              height: 100,
              child: Column(
                children: [
                  const Text(
                    'Materias',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: subjectsList.length,
                      itemBuilder: (context, index) {
                        String subjectName = subjectsList[index];

                        return ListTile(
                          title: Text(subjectName),
                          trailing: MouseRegion(
                            onEnter: (_) {
                              hideTimer?.cancel();
                              setState(() {
                                hoveredSubject = subjectName;
                              });
                            },
                            onExit: (_) {
                              hideTimer = Timer(
                                  const Duration(milliseconds: 1500), () {
                                if (mounted) {
                                  setState(() {
                                    hoveredSubject = null;
                                  });
                                }
                              });
                            },
                            child: const Icon(Icons.info_outline),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Display subject information
            if (hoveredSubject != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.white,
                child: Text(
                  'Información de $hoveredSubject\n'
                  'Profesor: ${subjectDetails[hoveredSubject]?['Profesor'] ?? 'No disponible'}\n'
                  'NRC: ${subjectDetails[hoveredSubject]?['NRC'] ?? 'No disponible'}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
