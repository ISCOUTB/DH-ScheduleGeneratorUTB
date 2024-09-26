// lib/widgets/schedule_grid_widget.dart
import 'package:flutter/material.dart';
import 'schedule_preview_widget.dart';

class ScheduleGridWidget extends StatelessWidget {
  final List<List<Map<String, List<String>>>> allSchedules;
  final Function(int) onScheduleTap;

  const ScheduleGridWidget({
    Key? key,
    required this.allSchedules,
    required this.onScheduleTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 3; // Número de cuadrículas por fila
    double spacing = 8;
    double totalSpacing = spacing * (crossAxisCount - 1);
    double gridWidth = (screenWidth - totalSpacing - 60) / crossAxisCount; // Restamos 60 del menú lateral

    return SingleChildScrollView(
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: List.generate(allSchedules.length, (index) {
          var schedule = allSchedules[index];
          return GestureDetector(
            onTap: () {
              onScheduleTap(index);
            },
            child: Container(
              width: gridWidth,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: SchedulePreviewWidget(schedule: schedule),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
