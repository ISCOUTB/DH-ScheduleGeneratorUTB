import 'package:flutter/material.dart';

class ScheduleGeneratorWidget extends StatelessWidget {
  final VoidCallback generateSchedule;

  const ScheduleGeneratorWidget({
    Key? key,
    required this.generateSchedule,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: generateSchedule,
        child: const Text('Generar Horario'),
      ),
    );
  }
}
