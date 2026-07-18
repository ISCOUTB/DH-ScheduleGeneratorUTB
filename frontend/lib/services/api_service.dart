import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import '../models/class_option.dart';
import '../models/custom_course.dart';
import '../models/schedule.dart';
import '../models/schedule_diagnosis.dart';
import '../models/subject.dart';
import '../models/subject_summary.dart';

import 'package:flutter/foundation.dart';

/// Resultado de generar horarios: la lista + si el backend la truncó por el
/// cap móvil (para mostrar "N+" en el contador).
class GenerateSchedulesResult {
  final List<List<ClassOption>> schedules;
  final bool truncated;

  /// Solo cuando [schedules] viene vacío: explica por qué. Null si hay horarios.
  final ScheduleDiagnosis? diagnosis;

  const GenerateSchedulesResult({
    required this.schedules,
    required this.truncated,
    this.diagnosis,
  });
}

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

  Future<GenerateSchedulesResult> generateSchedules({
    required List<Subject> subjects,
    required Map<String, dynamic> filters,
    required double creditLimit,
    bool isMobile = false,
    List<CustomCourse> activeCustomCourses = const [],
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
      // El backend limita los resultados solo si el cliente es móvil.
      "isMobile": isMobile,
      // Cursos personalizados activos: reemplazan la oferta de su materia.
      "customCourses":
          activeCustomCourses.map((c) => c.toGenerationJson()).toList(),
    };

    try {
      final response = await client.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        final List<dynamic> data = decoded['schedules'] as List<dynamic>;
        final bool truncated = decoded['truncated'] as bool? ?? false;

        final schedules = data.map<List<ClassOption>>((schedule) {
          return (schedule as List).map<ClassOption>((classOption) {
            return ClassOption.fromJson(classOption as Map<String, dynamic>);
          }).toList();
        }).toList();

        // Solo viene cuando no hubo horarios; explica por qué.
        final rawDiagnosis = decoded['diagnosis'];
        return GenerateSchedulesResult(
          schedules: schedules,
          truncated: truncated,
          diagnosis: rawDiagnosis == null
              ? null
              : ScheduleDiagnosis.fromJson(
                  rawDiagnosis as Map<String, dynamic>),
        );
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

  // ============================================================
  // Cursos personalizados
  // ============================================================

  /// Catálogo completo de materias (con y sin oferta) para el selector de un
  /// curso personalizado. El buscador normal usa [getAllSubjects].
  Future<List<SubjectSummary>> getSubjectsCatalog() async {
    final url = Uri.parse('$_baseUrl/api/subjects-catalog');
    final client = _createClient();
    try {
      final response = await client.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> decoded =
            json.decode(utf8.decode(response.bodyBytes));
        return decoded.map((j) => SubjectSummary.fromJson(j)).toList();
      }
      throw Exception('Error del servidor: ${response.statusCode}');
    } finally {
      client.close();
    }
  }

  /// Lista los cursos personalizados del usuario.
  Future<List<CustomCourse>> getCustomCourses() async {
    final url = Uri.parse('$_baseUrl/api/custom-courses');
    final client = _createClient();
    try {
      final response = await client.get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        return (decoded['customCourses'] as List)
            .map((j) => CustomCourse.fromJson(j as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('No autenticado');
      }
      throw Exception('Error del servidor: ${response.statusCode}');
    } finally {
      client.close();
    }
  }

  /// Crea un curso personalizado para una materia del catálogo.
  Future<CustomCourse> createCustomCourse({
    required String code,
    required String name,
    required List<Schedule> bloques,
    String? nrc,
    String? type,
    String? professor,
    String? campus,
    bool activo = true,
  }) async {
    final url = Uri.parse('$_baseUrl/api/custom-courses');
    final client = _createClient();
    try {
      final response = await client.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "code": code,
          "name": name,
          "bloques": bloques.map((s) => s.toJson()).toList(),
          "nrc": nrc,
          "type": type,
          "professor": professor,
          "campus": campus,
          "activo": activo,
        }),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        return CustomCourse.fromJson(
            decoded['customCourse'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('No autenticado');
      }
      // 404 (materia inexistente), 409 (NRC ya existe), 429 (límite): el backend
      // manda un `detail` con el mensaje exacto (incl. qué materia ocupa el NRC).
      throw Exception(_detailOr(response, 'Error del servidor: ${response.statusCode}'));
    } finally {
      client.close();
    }
  }

  /// Extrae `detail` del cuerpo de error de FastAPI, o un mensaje por defecto.
  String _detailOr(http.Response response, String fallback) {
    try {
      final d = json.decode(utf8.decode(response.bodyBytes));
      if (d is Map && d['detail'] is String) return d['detail'] as String;
    } catch (_) {}
    return fallback;
  }

  /// ¿El NRC ya existe en la oferta real? Devuelve el nombre de la materia que
  /// lo ocupa, o null si está libre. Para validar en vivo en el formulario.
  Future<String?> checkNrcTaken(String nrc) async {
    final url = Uri.parse(
        '$_baseUrl/api/custom-courses/nrc-check?nrc=${Uri.encodeComponent(nrc)}');
    final client = _createClient();
    try {
      final response = await client.get(url);
      if (response.statusCode == 200) {
        final d = json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        return d['taken'] == true ? d['name'] as String? : null;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Actualiza campos de un curso personalizado (incluye el switch `activo`).
  /// Solo se envían los campos no nulos.
  Future<CustomCourse> updateCustomCourse(
    int id, {
    List<Schedule>? bloques,
    String? nrc,
    String? type,
    String? professor,
    String? campus,
    bool? activo,
  }) async {
    final url = Uri.parse('$_baseUrl/api/custom-courses/$id');
    final client = _createClient();
    final body = <String, dynamic>{};
    if (bloques != null) body['bloques'] = bloques.map((s) => s.toJson()).toList();
    if (nrc != null) body['nrc'] = nrc;
    if (type != null) body['type'] = type;
    if (professor != null) body['professor'] = professor;
    if (campus != null) body['campus'] = campus;
    if (activo != null) body['activo'] = activo;
    try {
      final response = await client.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        return CustomCourse.fromJson(
            decoded['customCourse'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('No autenticado');
      }
      throw Exception(_detailOr(response, 'Error del servidor: ${response.statusCode}'));
    } finally {
      client.close();
    }
  }

  /// Elimina un curso personalizado por ID.
  Future<void> deleteCustomCourse(int id) async {
    final url = Uri.parse('$_baseUrl/api/custom-courses/$id');
    final client = _createClient();
    try {
      final response = await client.delete(url);
      if (response.statusCode == 200) return;
      if (response.statusCode == 404) {
        throw Exception('Curso personalizado no encontrado');
      } else if (response.statusCode == 401) {
        throw Exception('No autenticado');
      }
      throw Exception('Error del servidor: ${response.statusCode}');
    } finally {
      client.close();
    }
  }
}
