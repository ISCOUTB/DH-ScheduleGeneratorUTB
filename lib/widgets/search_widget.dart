import 'package:flutter/material.dart';

class SearchSubjectsWidget extends StatelessWidget {
  final TextEditingController subjectController;
  final List<Map<String, dynamic>> searchResults;
  final Function(String) searchSubject;
  final Function(String, List<Map<String, String>>, int) addCredits;

  const SearchSubjectsWidget({
    Key? key,
    required this.subjectController,
    required this.searchResults,
    required this.searchSubject,
    required this.addCredits,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: subjectController,
            decoration: InputDecoration(
              labelText: 'Buscar Materia',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  searchSubject(subjectController.text);
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              var subject = searchResults[index];
              String subjectName = subject['name'];
              int credits = subject['credits'];

              return ListTile(
                title: Text(subjectName),
                subtitle: Text('Créditos: $credits'),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    addCredits(subjectName, subject['schedule'], credits);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
