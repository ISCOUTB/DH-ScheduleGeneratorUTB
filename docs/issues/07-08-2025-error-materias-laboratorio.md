# Bug: materias de prácticas profesionales no aparecen como opciones válidas

- **Fecha detectado:** 2025-07-08
- **Módulo afectado:** backend (generación de combinaciones de horarios)
- **Gravedad:** Media

## Descripción del Problema

Las materias catalogadas como prácticas profesionales (que solo tienen clases tipo "Laboratorio") no se mostraban como opciones válidas en la generación automática de horarios. Esto ocurría debido a que la lógica en `repository.py` asumía que cualquier clase tipo "Laboratorio" debía estar acompañada por una clase "Teórica". Esto no es cierto para casos especiales como las prácticas profesionales.

## Cómo reproducir

**1.** Seleccionar una materia de prácticas profesionales que solo posea clases tipo "Laboratorio".
**2.** Intentar generar horarios con esa materia incluida.
**3.** Observar que dicha materia nunca se incluye en los horarios generados.

## Causa Técnica

La lógica en la función `_get_option_combinations` no consideraba la posibilidad de grupos compuestos únicamente por opciones de tipo "Laboratorio".

**Lógica anterior en Flutter (Correcta):**

```dart
if (opcionesTeoricas.isNotEmpty && opcionesPracticas.isNotEmpty) {
  for (var teorica in opcionesTeoricas) {
    for (var practica in opcionesPracticas) {
      combinaciones.add([teorica, practica]);
    }
  }
} else if (opcionesTeoricas.isNotEmpty) {
  for (var opcion in opcionesTeoricas) {
    combinaciones.add([opcion]);
  }
} else if (opcionesPracticas.isNotEmpty) {
  for (var opcion in opcionesPracticas) {
    combinaciones.add([opcion]);
  }
}
```

**Lógica en Python (incorrecta antes del arreglo):**

```Python
if teoricas and labs:
    combinations.extend([[t, l] for t in teoricas for l in labs])
elif teoricas:
    combinations.extend([[t] for t in teoricas])
```

Como se observa, la rama `elif labs:`no existía en Python, impidiendo que se incluyeran grupos que solo tuvieran laboratorios.

## Solución aplicada

Se agregó la rama `elif` faltante para contemplar opciones que solo tengan laboratorios.

```python
// ...
if teoricas and labs:
    combinations.extend([[t, l] for t in teoricas for l in labs])
# Combinaciones de 'Teórico' solo
elif teoricas:
    combinations.extend([[t] for t in teoricas])
# Combinaciones de 'Laboratorio' solo
elif labs:
    combinations.extend([[l] for l in labs]) # Rama añadida
// ...
```

Esto corrige el bug, permitiendo que materias con solamente laboratorios (como las prácticas profesionales) sean tomadas en cuenta correctamente.

## Medidas adicionales

Se implementarán mayores precauciones al procesar los datos obtenidos de la API de Banner. Si se detecta que un curso afirma tener una sección asociada (isSectionLinked) pero no se encuentra el curso correspondiente, se considerará una anomalía crítica. Se tomarán medidas para reportarla y evitar que datos inconsistentes ingresen a la base de datos.
