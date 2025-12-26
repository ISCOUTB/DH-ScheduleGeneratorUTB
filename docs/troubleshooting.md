# Registro de Errores y Soluciones

Este documento mantiene un registro de los problemas encontrados durante el desarrollo y sus soluciones.

---

## 2024-12-23: Filtros de NRC - Actualización Dinámica y Persistencia

### Problema

Los filtros de NRC no se comportaban correctamente cuando se agregaban múltiples materias con cruces de horario:

1. **Problema Inicial**: Al agregar una segunda materia, los filtros de NRC de la primera materia no se actualizaban para mostrar solo las opciones viables (sin cruces de horario).

2. **Problema de Persistencia**: Cuando el usuario seleccionaba un NRC en el filtro, automáticamente desaparecían las demás opciones, impidiendo probar diferentes combinaciones.

3. **Comportamiento Esperado**: 
   - Materia 1 tiene 3 cursos (NRCs)
   - Al agregar Materia 2 con un curso que tiene cruce con uno de los NRCs de Materia 1
   - El filtro de Materia 1 debería mostrar solo 2 NRCs viables
   - Al seleccionar uno de esos 2 NRCs, el otro debe permanecer visible para poder probar diferentes combinaciones

### Intentos de Solución

#### Intento 1: Basado en Horarios Generados
- **Enfoque**: Calcular NRCs viables analizando los horarios generados por la API
- **Problema**: Los filtros se recalculaban basándose en los horarios ya filtrados, creando un ciclo donde seleccionar un NRC hacía desaparecer los demás
- **Código**:
  ```dart
  Map<String, Set<String>> getViableNrcsFromSchedules() {
    // Analizaba _allSchedules para extraer NRCs viables
    for (var schedule in _allSchedules) {
      for (var classOption in schedule) {
        viableNrcs[classOption.subjectCode]!.add(classOption.nrc);
      }
    }
  }
  ```

#### Intento 2: Detección Simplista de Cruces
- **Enfoque**: Detectar cruces comparando directamente los cursos sin analizar horarios generados
- **Problema Inicial**: Usaba propiedades incorrectas del modelo (`codigo` en lugar de `code`)
- **Problema Secundario**: Asumía que `ClassOption` tenía propiedades `day` y `time` directamente, cuando en realidad tiene una lista `schedules`
- **Problema de Detección**: Solo comparaba si los horarios eran exactamente iguales (`schedule1.time == schedule2.time`), no detectaba solapamientos

### Solución Final

#### Enfoque
Detección directa de cruces de horario comparando todos los horarios de cada curso, con verificación de solapamiento de rangos de tiempo.

#### Implementación

**1. Método Principal - Cálculo de NRCs Viables** (`schedule_provider.dart`)
```dart
Map<String, Set<String>> getViableNrcsFromSchedules() {
  final Map<String, Set<String>> viableNrcsMap = {};
  
  if (_addedSubjects.isEmpty) {
    return viableNrcsMap;
  }

  // Para cada materia agregada
  for (var subject in _addedSubjects) {
    final viableNrcs = <String>{};
    
    // Revisar cada curso (NRC) de esta materia
    for (var course in subject.classOptions) {
      bool hasConflict = false;
      
      // Verificar si este curso tiene cruce con algún curso de otras materias
      for (var otherSubject in _addedSubjects) {
        // Saltar la misma materia
        if (otherSubject.code == subject.code) continue;
        
        // Revisar cada curso de la otra materia
        for (var otherCourse in otherSubject.classOptions) {
          if (_coursesHaveConflict(course, otherCourse)) {
            hasConflict = true;
            break;
          }
        }
        
        if (hasConflict) break;
      }
      
      // Si no tiene cruce, es viable
      if (!hasConflict) {
        viableNrcs.add(course.nrc);
      }
    }
    
    viableNrcsMap[subject.code] = viableNrcs;
  }
  
  return viableNrcsMap;
}
```

**2. Detección de Cruces con Solapamiento de Rangos**
```dart
bool _coursesHaveConflict(ClassOption course1, ClassOption course2) {
  // Revisar todos los horarios de ambos cursos
  for (var schedule1 in course1.schedules) {
    for (var schedule2 in course2.schedules) {
      // Si tienen el mismo día y hora exacta, hay cruce
      if (schedule1.day == schedule2.day && schedule1.time == schedule2.time) {
        return true;
      }
      
      // Verificar solapamiento de horarios (ej: "07:00 - 09:00" vs "08:00 - 10:00")
      if (schedule1.day == schedule2.day) {
        try {
          // Parsear rangos de tiempo "HH:MM - HH:MM"
          final range1 = schedule1.time.split(' - ');
          final range2 = schedule2.time.split(' - ');
          
          if (range1.length == 2 && range2.length == 2) {
            final start1 = _timeToMinutes(range1[0].trim());
            final end1 = _timeToMinutes(range1[1].trim());
            final start2 = _timeToMinutes(range2[0].trim());
            final end2 = _timeToMinutes(range2[1].trim());
            
            // Hay solapamiento si: start1 < end2 AND end1 > start2
            if (start1 < end2 && end1 > start2) {
              return true;
            }
          }
        } catch (e) {
          // Si hay error al parsear, continuar verificando
        }
      }
    }
  }
  
  return false;
}
```

**3. Conversión de Tiempo para Comparación Numérica**
```dart
int _timeToMinutes(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return 0;
  
  final hours = int.tryParse(parts[0]) ?? 0;
  final minutes = int.tryParse(parts[1]) ?? 0;
  
  return hours * 60 + minutes;
}
```

#### Puntos Clave de la Solución

1. **Independencia de Filtros Aplicados**: El cálculo de NRCs viables se basa en los datos originales de las materias (`_addedSubjects`), no en los horarios generados (`_allSchedules`)

2. **Detección de Solapamiento**: No solo compara igualdad exacta, sino que detecta cuando dos rangos de tiempo se solapan usando lógica de intervalos

3. **Estructura del Modelo**: 
   - `Subject` tiene `code` (no `codigo`)
   - `ClassOption` tiene `schedules` (lista de objetos `Schedule`)
   - `Schedule` tiene `day` y `time`

4. **Iteración Completa**: Se revisan todos los horarios de cada curso, ya que un curso puede tener múltiples sesiones (ej: L/Mi 07:00-09:00)

### Archivos Modificados

- `frontend/lib/providers/schedule_provider.dart`:
  - Agregado método `getViableNrcsFromSchedules()`
  - Agregado método `_coursesHaveConflict()`
  - Agregado método `_timeToMinutes()`

### Resultado

Los filtros de NRC ahora:
- Muestran solo cursos sin cruces de horario
- Se actualizan cuando se agregan/eliminan materias
- Permanecen visibles después de seleccionar una opción
- Detectan solapamientos de tiempo, no solo igualdades exactas
- Son independientes de los filtros aplicados por el usuario

---
