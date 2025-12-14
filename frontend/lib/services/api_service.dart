import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/class_option.dart';
import '../models/subject.dart';
import '../models/subject_summary.dart';

import 'package:flutter/foundation.dart';

class ApiService {
  // En desarrollo: localhost (nginx puerto 80 hace proxy a /api/*)
  // En producción: rutas relativas (mismo dominio)
  static const String _baseUrl = kDebugMode ? "http://localhost" : "";

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

  Future<Subject> getSubjectDetails(
      String subjectCode, String subjectName) async {
    // Codifica el nombre de la materia para que sea seguro en una URL (ej: "Ética y Cívica" -> "Ética%20y%20Cívica")
    final encodedSubjectName = Uri.encodeComponent(subjectName);
    final url = Uri.parse(
        '$_baseUrl/api/subjects/$subjectCode?name=$encodedSubjectName');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Decodificación UTF-8 para manejar tildes y caracteres especiales.
        final decodedBody = utf8.decode(response.bodyBytes);
        return Subject.fromJson(json.decode(decodedBody));
      } else {
        throw Exception(
            'Error del servidor al obtener detalles: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en la petición a la API de detalles: $e');
      rethrow;
    }
  }

  Future<List<List<ClassOption>>> generateSchedules({
    required List<Subject> subjects,
    required Map<String, dynamic> filters,
    required int creditLimit,
  }) async {
    final url = Uri.parse('$_baseUrl/api/schedules/generate');

    // Se crea una lista de mapas.
    // Cada mapa contiene el código y el nombre exacto de la materia.
    final subjectsPayload = subjects
        .map((s) => {
              'code': s.code,
              'name': s.name,
            })
        .toList();

    final payload = {
      "subjects": subjectsPayload,
      "filters": filters, // Los filtros se mantienen igual
      "creditLimit": creditLimit,
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
