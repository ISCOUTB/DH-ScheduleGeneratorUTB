// lib/data_loader/subject_data.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subject.dart';

Future<List<Subject>> fetchSubjectsFromApi() async {
  final response =
      await http.get(Uri.parse('http://20.255.98.63:8000/subjects'));

  if (response.statusCode == 200) {
    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((e) => Subject.fromJson(e)).toList();
  } else {
    throw Exception('Error al obtener materias: ${response.statusCode}');
  }
}
