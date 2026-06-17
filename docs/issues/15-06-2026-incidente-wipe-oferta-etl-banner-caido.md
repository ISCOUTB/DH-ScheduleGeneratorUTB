# Incidente: borrado de la oferta académica cuando Banner está caído

- Fecha: 2026-06-15
- Estado: Resuelto
- Tipo: Pérdida de datos / robustez del ETL
- Relacionado: `29-03-2026-politica-persistencia-etl.md`

## 1. Síntoma

`GET /api/subjects` en producción devolvía `[]` (sin materias). La app cargaba pero no se podían buscar materias ni generar horarios. Los favoritos seguían mostrando su grilla, pero el estado de cupos salía todo en gris ("eliminado").

## 2. Causa raíz

El pipeline ETL (`actualizar_datos.py`) corre periódicamente (cron cada ~10 min) y en cada deploy (`initial-data`). El flujo era:

1. `descargar_json.py` pedía la oferta a Banner. Ante un **HTTP 502** (Banner caído), hacía `break` y trataba el error igual que "fin de paginación" → escribía `{"data": []}` (sobrescribiendo el cache válido) **sin lanzar excepción**.
2. `insertar_en_db.py` → `actualizar_base()` leía ese JSON vacío, obtenía 0 cursos y **limpiaba** `Clase/Curso/Profesor/Materia` e insertaba 0 dentro de la transacción atómica, que **commiteaba con éxito** (no hubo excepción → no hubo rollback).

La política de persistencia (29-03-2026) garantizaba rollback **ante excepciones**, pero un **dataset vacío** se "inserta" sin error → borraba toda la oferta. Las tablas funcionales (`usuario`, `sesion_usuario`, `horario_destacado`) nunca se vieron afectadas.

**Disparador:** cualquier corrida del ETL (cron o `initial-data` de un deploy) mientras Banner devolvía 502. Con Banner inestable, la oferta oscilaba entre llena (corrida exitosa) y vacía (corrida durante la caída).

## 3. Impacto

- Oferta académica (materias/cursos) vacía en producción durante la caída de Banner.
- **Sin pérdida** de datos de usuario (favoritos, sesiones, identidad).
- La oferta académica **no tiene backup** (`hacer_snapshot()` solo respalda tablas funcionales); solo se recupera re-descargando de Banner.

## 4. Solución (defensa en profundidad)

1. `descargar_json.py`: lanza excepción ante `HTTP != 200` (descarga incompleta) o 0 resultados, y **no** sobrescribe el cache con vacío.
2. `actualizar_datos.py`: si la descarga falla, **omite el ciclo** sin tocar la base (mensaje claro; el cron reintenta en la próxima corrida).
3. `insertar_en_db.py` → `actualizar_base()`: **guard** que aborta sin limpiar si el dataset llega sin cursos/materias.

Efecto: el ETL solo limpia/reescribe la oferta cuando hay una descarga **completa y no vacía**. Ante caída de Banner, conserva lo existente.

## 5. Recuperación

Automática: cuando Banner vuelve a responder, la siguiente corrida del cron descarga la oferta completa y repuebla la base. Con el fix, una vez poblada **se mantiene** (no se re-borra en la próxima caída).

## 6. Prevención / pendientes

- (Hecho) Guards en los tres puntos del pipeline.
- (Recomendado) Test automático: alimentar `actualizar_base()` con dataset vacío y verificar que **no** limpia las tablas; y que `descargar_json` lanza ante 502/0.
- (Futuro) Guard por **umbral**: abortar si la descarga nueva trae muchos menos cursos que los actuales (protege ante descargas parciales no-vacías).
- (Futuro) Backup también de la oferta académica, o desacoplar `initial-data` de cada deploy.
