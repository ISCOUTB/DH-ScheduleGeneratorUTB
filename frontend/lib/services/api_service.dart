import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import '../models/class_option.dart';
import '../models/subject.dart';
import '../models/subject_summary.dart';

import 'package:flutter/foundation.dart';

class ApiService {
  // En desarrollo: localhost (nginx puerto 80 hace proxy a /api/*)
  // En producción: rutas relativas (mismo dominio)
  static const String _baseUrl = kDebugMode ? "http://localhost" : "";

  /// Crea un cliente HTTP que envía cookies (necesario para web).
  http.Client _createClient() {
    if (kIsWeb) {
      final client = BrowserClient();
      client.withCredentials = true;
      return client;
    }
    return http.Client();
  }

  // Obtiene una lista de todas las materias disponibles.
  Future<List<SubjectSummary>> getAllSubjects() async {
    final url = Uri.parse('$_baseUrl/api/subjects');
    final client = _createClient();
    try {
      final response = await client.get(url);

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
      debugPrint('Error en la petición a la API de materias: $e');
      throw Exception('No se pudo obtener la lista de materias.');
    } finally {
      client.close();
    }
  }

  Future<Subject> getSubjectDetails(
      String subjectCode, String subjectName) async {
    // Codifica el nombre de la materia para que sea seguro en una URL (ej: "Ética y Cívica" -> "Ética%20y%20Cívica")
    final encodedSubjectName = Uri.encodeComponent(subjectName);
    final url = Uri.parse(
        '$_baseUrl/api/subjects/$subjectCode?name=$encodedSubjectName');
    final client = _createClient();

    try {
      final response = await client.get(url);

      if (response.statusCode == 200) {
        // Decodificación UTF-8 para manejar tildes y caracteres especiales.
        final decodedBody = utf8.decode(response.bodyBytes);
        return Subject.fromJson(json.decode(decodedBody));
      } else {
        throw Exception(
            'Error del servidor al obtener detalles: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error en la petición a la API de detalles: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<List<List<ClassOption>>> generateSchedules({
    required List<Subject> subjects,
    required Map<String, dynamic> filters,
    required int creditLimit,
  }) async {
    final url = Uri.parse('$_baseUrl/api/schedules/generate');
    final client = _createClient();

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
      final response = await client.post(
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
    } finally {
      client.close();
    }
  }

  // ============================================================
  // Favoritos (Horarios Destacados)
  // ============================================================

  /// Obtiene los horarios destacados del usuario para un término.
  Future<Map<String, dynamic>> getFavorites({String? term}) async {
    final queryParams = term != null ? '?term=$term' : '';
    final url = Uri.parse('$_baseUrl/api/favorites$queryParams');
    final client = _createClient();

    try {
      final response = await client.get(url);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else if (response.statusCode == 401) {
        throw Exception('No autenticado');
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// Obtiene el estado actual de cupos de una lista de NRCs (Fase 2).
  ///
  /// Retorna `{ nrc: {available, total} }`. Los NRC inexistentes en `Curso`
  /// no aparecen en la respuesta (el llamador los trata como eliminados).
  /// Solo debe usarse para el término actual.
  Future<Map<String, Map<String, int>>> getFavoritesStatus(
      List<String> nrcs) async {
    if (nrcs.isEmpty) return {};
    final url =
        Uri.parse('$_baseUrl/api/favorites/status?nrcs=${nrcs.join(',')}');
    final client = _createClient();

    try {
      final response = await client.get(url);

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        return decoded.map((nrc, value) => MapEntry(nrc, {
              'available': (value['available'] as num).toInt(),
              'total': (value['total'] as num).toInt(),
            }));
      } else if (response.statusCode == 401) {
        throw Exception('No autenticado');
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// Obtiene los términos disponibles con favoritos + el término actual.
  Future<Map<String, dynamic>> getFavoriteTerms() async {
    final url = Uri.parse('$_baseUrl/api/favorites/terms');
    final client = _createClient();

    try {
      final response = await client.get(url);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else if (response.statusCode == 401) {
        throw Exception('No autenticado');
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// Crea un horario destacado.
  Future<Map<String, dynamic>> createFavorite({
    required String signature,
    required List<Map<String, dynamic>> schedule,
  }) async {
    final url = Uri.parse('$_baseUrl/api/favorites');
    final client = _createClient();

    try {
      final response = await client.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "signature": signature,
          "schedule": schedule,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else if (response.statusCode == 409) {
        throw Exception('Este horario ya está en tus destacados');
      } else if (response.statusCode == 429) {
        throw Exception('Límite de horarios destacados alcanzado');
      } else if (response.statusCode == 401) {
        throw Exception('No autenticado');
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// Elimina un horario destacado por ID.
  Future<void> deleteFavorite(int favoriteId) async {
    final url = Uri.parse('$_baseUrl/api/favorites/$favoriteId');
    final client = _createClient();

    try {
      final response = await client.delete(url);

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 404) {
        throw Exception('Favorito no encontrado');
      } else if (response.statusCode == 401) {
        throw Exception('No autenticado');
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }
}
