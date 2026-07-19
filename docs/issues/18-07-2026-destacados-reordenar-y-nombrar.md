# Horarios destacados: reordenar, nombrar y arreglos de período

- Fecha: 2026-07-18
- Estado: Implementado (solo escritorio)
- Alcance: BD (2 columnas), Backend (repo + endpoints), Frontend (provider + pantalla de Destacados)

## Objetivo

Que el usuario pueda **reordenar** sus horarios destacados arrastrándolos en el
sidebar de la pantalla de Destacados, y **ponerles un nombre** propio; ambos con
**persistencia** (por usuario, no por sesión). De paso se corrigieron dos bugs de
sincronización entre períodos y una regresión visual.

## Modelo (BD)

Dos columnas nuevas en `horario_destacado` (nullables; migración idempotente con
backfill, igual que `etiqueta`; datos viejos intactos):

- `nombre VARCHAR` — nombre editable. `NULL` → se muestra el rótulo automático
  "Opción X".
- `posicion INTEGER` — orden manual persistente (0-indexado por usuario+term). Se
  backfillea desde `created_at` para los favoritos existentes.

Migración: `_agregar_nombre_posicion_favoritos` en `migrar_esquema.py`.

## Backend

- `get_favorites` ordena por `posicion` (`ORDER BY posicion ASC NULLS LAST, created_at, id`) y devuelve `nombre`, `posicion`, `created_at`.
- `create_favorite` asigna `posicion = MAX(posicion)+1` → el nuevo va al final (cola).
- Nuevos `rename_favorite(id, uid, nombre)` y `reorder_favorites(uid, term, ordered_ids)`.
- Endpoints: `PATCH /api/favorites/{id}` (nombre) y `PATCH /api/favorites/reorder` (lista de IDs). `reorder` se define antes que `{id}` para que no lo capture la ruta con parámetro.

## Frontend / UX

- **Reordenar:** el sidebar de Destacados es un `ReorderableListView`; se arrastra
  una tarjeta y el orden se guarda (`reorderFavorite` → `PATCH /reorder`). El tap
  sigue seleccionando.
- **Nombrar (inline):** el ✏️ junto al título en la vista grande convierte
  "Opción X" en un campo editable (texto preseleccionado). **Enter**, el **✓**, o
  **clic afuera** guardan. Vacío o igual al rótulo automático → sin nombre (vuelve
  a la letra). El nombre **reemplaza** por completo el "Opción X" (header + tarjeta).
- **Cola (FIFO):** un destacado nuevo va al final (antes se insertaba al frente,
  "pila", lo que corría las letras).

### Rótulo automático ESTABLE (decisión clave)

La letra "Opción A/B/C…" se calcula por **orden de creación** (`created_at`), **no
por posición**. Así, al reordenar, cada horario **conserva su letra** (mueves el
"Opción B" arriba y sigue siendo "B"). La letra es identidad del horario, no su
posición — que era la intención al desligar nombre/orden de la letra. Al borrar
uno, al recargar las letras se recompactan por creación.

### Etiqueta de la esquina (mini-grilla)

La esquina superior izquierda de cada grilla muestra **`nombre ?? letra estable`**,
truncada con ellipsis si el nombre es largo (el completo se ve al abrir el
detalle). Para esto `ScheduleGridWidget` acepta un `labelBuilder(index)` que tiene
prioridad sobre la letra posicional interna.

- **Escritorio:** grilla grande y mini-previews del sidebar usan `labelBuilder`/`fillParentLabel`.
- **Móvil:** antes la grilla rotulaba con letra **posicional** (siempre A, B, C…
  sin importar el orden/nombre). Ahora usa `labelBuilder` → la misma letra estable
  o el nombre, consistente con escritorio.

Guardado de nombre (edge cases): al guardar se hace `trim()` y se compara con el
rótulo automático; si el resultado queda vacío o es exactamente "Opción X", se
guarda **sin nombre** (queda la letra). Así, abrir el editor sin cambiar nada,
reescribir el mismo default, o dejar espacios de más, **no** cuentan como nombrar.

## Bugs corregidos (sincronización entre períodos)

El estado de la estrella del generador estaba atado al **período que se veía** en
Destacados. Al navegar a un período anterior:
1. La estrella del generador mostraba "sin destacar" pero al pulsarla decía "ya
   está destacado".
2. Destacar uno nuevo lo hacía aparecer en la lista del **período viejo**.

**Causa:** `_favoriteSignatures`/`_favoriteIdBySignature` se recargaban con el
período navegado. **Fix:** se separó el estado:
- `_curSig`/`_curId` = término **actual**, siempre (los usa la estrella/toggle del
  generador; no se tocan al navegar a períodos pasados).
- `_favoriteSignatures`/`_favoriteIdBySignature`/`_favoriteSchedules`/`_favoriteNames`/`_favoriteCreatedAt` = término **visto** (Destacados).
- Al destacar/quitar en el generador, la lista vista solo se sincroniza si se está
  viendo el término actual.

## Regresión corregida

La leyenda de colores de estado se había "centrado" al meter un `Flexible` en el
título del header (le robaba espacio al `Expanded` de la leyenda). Se volvió a
`ConstrainedBox`; la leyenda se ancla de nuevo a la derecha.

## Fuera de alcance

**Móvil:** **reordenar** y **editar nombre** siguen siendo solo de escritorio
(la vista móvil es una grilla, no una lista arrastrable, y no tiene tarjeta/header
donde poner el editor). Sí se corrigió la etiqueta de la esquina para que muestre
`nombre ?? letra estable` (antes eran letras posicionales); ver la sección de
etiqueta de la esquina.

## Despliegue

Backend + migración deben ir juntos (la migración corre en el ETL:
`actualizar_datos.py` → `aplicar_migraciones`). En local, el `.ps1` de dev levanta
`cron-updater` (cuyo cron corre el ETL) y reconstruye `backend`, por lo que las
columnas y el código nuevo quedan disponibles.
