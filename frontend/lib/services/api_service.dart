import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/class_option.dart';
import '../models/subject.dart';
import '../models/subject_summary.dart';

class ApiService {
  // La URL base ahora está vacía. Las peticiones serán relativas al dominio actual.
  // Por ejemplo, si estás en 'midominio.com', pedirá a 'midominio.com/api/subjects'.
  static const String _baseUrl = "";

  // Obtiene una lista de todas las materias disponibles.
  Future<List<SubjectSummary>> getAllSubjects() async {
    final url = Uri.parse('$_baseUrl/api/subjects');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> decodedList =
            json.decode(utf8.decode(response.bodyBytes));

        // Mapea la lista decodificada a una lista de SubjectSummary
        // No es necesario acceder a 'classOptions' porque este modelo es ligero.
        return decodedList
            .map((json) => SubjectSummary.fromJson(json))
            .toList();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en la petición a la API de materias: $e');
      throw Exception('No se pudo obtener la lista de materias.');
    }
  }

  // --- NUEVO MÉTODO PARA OBTENER DETALLES DE UNA MATERIA ---
  Future<Subject> getSubjectDetails(String subjectCode) async {
    final url = Uri.parse('$_baseUrl/api/subjects/$subjectCode');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return Subject.fromJson(data);
      } else {
        throw Exception(
            'Error del servidor al obtener detalles: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en la petición a la API de detalles: $e');
      throw Exception('No se pudo obtener los detalles de la materia.');
    }
  }

  Future<List<List<ClassOption>>> generateSchedules({
    required List<Subject> subjects,
    required Map<String, dynamic> filters,
    required int creditLimit,
  }) async {
    final url = Uri.parse('$_baseUrl/api/schedules/generate');

    final subjectCodes = subjects.map((s) => s.code).toList();

    final payload = {
      "subjects": subjectCodes,
      "filters": {
        ...filters,
        "max_credits": creditLimit,
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

        return data.map<List<ClassOption>>((schedule) {
          return (schedule as List).map<ClassOption>((classOption) {
            return ClassOption.fromJson(classOption as Map<String, dynamic>);
          }).toList();
        }).toList();
      } else {
        print('Error del servidor: ${response.statusCode}');
        print('Cuerpo de la respuesta: ${response.body}');
        throw Exception('Error al generar horarios desde la API');
      }
    } catch (e) {
      print('Error en la petición a la API: $e');
      throw Exception('No se pudo conectar al servidor.');
    }
  }
}
