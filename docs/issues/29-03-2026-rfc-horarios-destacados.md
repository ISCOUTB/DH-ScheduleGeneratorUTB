# RFC: Horarios Destacados por Usuario

- Fecha: 2026-03-29
- Estado: En implementación (fase de persistencia de usuario completada)
- Autor: Equipo Backend/Frontend
- Alcance: Backend API, autenticación, modelo de datos, frontend de horarios

## 1. Contexto

Actualmente la aplicación genera horarios bajo demanda y no persiste todas las combinaciones (decisión correcta por costo y escala).

Se necesita permitir que cada usuario guarde horarios destacados (favoritos) para consultarlos después.

## 2. Verificación Técnica Inicial

### 2.1 Tabla de usuarios

Resultado:
- La tabla `usuario` sí está definida en `backend/init.sql`.
- Campos actuales: `id`, `entra_id`, `email`, `nombre`, `created_at`.

### 2.2 Uso real en runtime

Resultado:
- Existen funciones de repositorio para persistir usuario:
  - `get_or_create_user`
  - `get_user_by_id`
- El flujo de autenticación actual usa sesiones en memoria (`sessions` dict) y cookie `session_id`.
- Las funciones de repositorio de usuario no están conectadas al login actual.

Implicación:
- Hoy puede existir la tabla pero no estar siendo usada consistentemente en cada autenticación.

### 2.3 Actualización aplicada (2026-03-29)

Se implementó el wiring mínimo para persistencia de usuario:

1. El callback OAuth ahora crea/obtiene usuario en DB (`get_or_create_user`).
2. La sesión guarda `db_user_id` además del `oid` de Entra.
3. El endpoint `/api/auth/me` expone `dbUserId` para trazabilidad.

Limitación vigente:
- El almacén de sesiones sigue en memoria del proceso API.

## 3. Problema

Sin una entidad de favoritos:
- El usuario pierde sus horarios preferidos entre sesiones/dispositivos.
- No existe forma auditable de saber qué horario guardó cada usuario.
- No hay endpoint dedicado para favoritos.

## 4. Objetivos

1. Guardar horarios destacados por usuario autenticado.
2. Evitar duplicados de favoritos.
3. No modificar la estrategia de generación masiva de horarios (seguir on-demand).
4. Implementar con cambios incrementales y bajo riesgo.

## 5. No Objetivos

1. No persistir todas las combinaciones generadas.
2. No rediseñar el algoritmo de backtracking.
3. No migrar a un sistema de sesiones distribuido en esta fase.

## 6. Diseño Propuesto

## 6.1 Modelo de datos

Nueva tabla propuesta: `horario_destacado`

Campos:
- `id` SERIAL PK
- `usuario_id` INTEGER NOT NULL FK -> `usuario.id`
- `term` VARCHAR NOT NULL
- `signature` VARCHAR NOT NULL
- `schedule_json` JSONB NOT NULL
- `created_at` TIMESTAMP DEFAULT NOW()

Restricciones:
- `UNIQUE (usuario_id, term, signature)`

Motivación:
- `signature` evita duplicados del mismo horario.
- `schedule_json` preserva snapshot exacto mostrado al usuario.

## 6.2 Contrato API

Nuevos endpoints:

1. `GET /api/favorites/schedules?term=202610`
- Devuelve favoritos del usuario autenticado para un término.

2. `POST /api/favorites/schedules`
- Body:
  - `term`
  - `signature`
  - `schedule` (snapshot serializado)
- Crea favorito si no existe.

3. `DELETE /api/favorites/schedules/{favorite_id}`
- Elimina favorito del usuario autenticado.

Autorización:
- Usar la cookie de sesión actual (`session_id`) y resolver usuario autenticado.
- Recomendado: conectar login con `get_or_create_user` para persistir usuario al autenticar.

## 6.3 Frontend

Cambios mínimos:
- Botón estrella en tarjetas de horario.
- Estado local de favoritos por `signature`.
- Sin cambios al endpoint de generación (`/api/schedules/generate`) en esta fase.

## 7. Plan de Implementación (Incremental)

Fase 1: Base de datos y wiring de usuario
1. Crear migración SQL para `horario_destacado`.
2. En callback de auth, invocar `get_or_create_user`.
3. Guardar en sesión el `user_db_id`.

Fase 2: Endpoints de favoritos
1. Implementar rutas CRUD mínimas para favoritos.
2. Agregar validación de ownership por usuario.
3. Manejar idempotencia en `POST` (si existe, retornar existente).

Fase 3: Frontend
1. Consumir endpoints de favoritos.
2. Marcar/desmarcar estrellas.
3. Filtro opcional de "solo destacados".

## 8. Riesgos y Mitigaciones

Riesgo 1: Sesiones en memoria se pierden al reiniciar API.
- Mitigación: A corto plazo, aceptable para MVP.
- Futuro: migrar sesiones a Redis/DB.

Riesgo 2: `init.sql` no se reaplica en volúmenes existentes.
- Mitigación: usar migraciones versionadas para cambios nuevos.

Riesgo 3: Tamaño de `schedule_json`.
- Mitigación: limitar cantidad de favoritos por usuario (opcional) y validar payload.

## 9. Pruebas Requeridas

Backend:
1. Crear favorito nuevo.
2. Evitar duplicado por `(usuario_id, term, signature)`.
3. Listar favoritos por término.
4. Eliminar favorito propio.
5. Prohibir eliminación de favorito de otro usuario.

Frontend:
1. Estado de estrella consistente al recargar.
2. Toggle favorito sin romper vista de horarios.
3. Manejo de errores de red con feedback UI.

## 10. Criterios de Aceptación

1. Usuario autenticado puede guardar y eliminar horarios destacados.
2. Favoritos persisten entre sesiones (mientras exista usuario en DB).
3. No se modifica ni degrada la generación de horarios actual.
4. Documentación actualizada en `docs/modelo_datos.md`.

## 11. Decisión

Aprobar enfoque incremental con tabla `horario_destacado` y sin modificar el contrato actual de generación en esta fase.
