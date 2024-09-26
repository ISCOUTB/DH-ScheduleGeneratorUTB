import 'package:flutter/material.dart';

class AddedSubjectsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> addedSubjects;
  final int usedCredits;
  final int creditLimit;

  const AddedSubjectsWidget({
    Key? key,
    required this.addedSubjects,
    required this.usedCredits,
    required this.creditLimit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: addedSubjects.length,
            itemBuilder: (context, index) {
              var subject = addedSubjects[index];
              String subjectName = subject['name'];
              int credits = subject['credits'];
              List<Map<String, String>> schedule = subject['schedule'];

              return ListTile(
                title: Text(subjectName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Créditos: $credits'),
                    ...schedule.map((s) => Text('${s['day']}: ${s['time']}')),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Créditos utilizados: $usedCredits / $creditLimit'),
        ),
      ],
    );
  }
}
