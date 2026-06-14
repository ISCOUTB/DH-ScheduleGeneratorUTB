# RFC: Horarios Destacados — Fase 2 y 3

- Fecha: 2026-05-12
- Estado: Propuesta
- Autor: Equipo Backend/Frontend
- Alcance: Backend (API, jobs), Frontend (grilla de favoritos, configuración)
- Feature padre: Horarios Destacados
- Fases previas:
  - **Fase 1** ✅ — Persistencia y pantalla de visualización (`29-03-2026-rfc-horarios-destacados.md`, `12-05-2026-pantalla-horarios-destacados.md`)

> **Revisión 2026-06-14 (antes de implementar Fase 2):** se corrigió la RFC contra el código real. Cambios: (1) los cupos viven en la tabla **`Curso`** (`CuposDisponibles`, `CuposTotales`), no existe `secciones`; (2) el repositorio usa **psycopg síncrono** + `run_in_threadpool`, no asyncpg; (3) el `NRC` es **entero** en BD (se expone como string en los modelos), hay que parsear; (4) el estado de cupos **solo aplica al término actual** — ver §2.6.

## 1. Contexto

La feature "Horarios Destacados" se divide en tres fases:

| Fase | Descripción | Estado |
|------|-------------|--------|
| **1** | Tabla `horario_destacado`, endpoints CRUD, pantalla con sidebar y previsualización | ✅ Implementada |
| **2** | Estado visual de cursos por cupos (colores en la grilla) | 📋 Esta RFC |
| **3** | Notificaciones por correo al cambiar estado de un curso | 📋 Esta RFC |

Las fases 2 y 3 son independientes entre sí pero comparten la misma base de datos y lógica de estado. La fase 2 es requisito lógico (no técnico) de la fase 3: primero hay que definir los umbrales de estado antes de poder notificar sobre cambios.

## 2. Fase 2: Estado Visual de Cursos

### 2.1 Problema

Actualmente los bloques de la grilla de horarios destacados se colorean por **materia** (igual que en la generación). Sin embargo, para un horario guardado lo relevante es saber si los cupos de cada sección siguen disponibles.

### 2.2 Objetivo

Colorear cada bloque de clase en la grilla de favoritos según el estado actual de cupos de su NRC:

| Estado | Color fondo | Color borde | Condición |
|--------|-------------|-------------|-----------|
| **Seguro** 🟢 | `#D4EDDA` | `#28A745` | `cuposDisponibles / cuposTotales > 50%` |
| **Precaución** 🟡 | `#FFECD2` | `#E67E22` | `cuposDisponibles / cuposTotales` entre 20% y 50% |
| **En riesgo** 🔴 | `#F8D7DA` | `#DC3545` | `cuposDisponibles / cuposTotales < 20%` y `cuposDisponibles > 0` |
| **Eliminado** ⚫ | `#E9ECEF` | `#ADB5BD` | `cuposDisponibles == 0` |

> **Nota:** Los umbrales (50%, 20%) son propuestas iniciales. Se pueden ajustar según feedback de usuarios.

### 2.3 Datos disponibles

Ya se cuenta con la información necesaria:

- **En BD:** La tabla **`Curso`** tiene columnas `CuposDisponibles` y `CuposTotales` (PK `NRC`, tipo **entero**), actualizadas periódicamente por el cron ETL (`scripts/actualizar_datos.py`). El ETL **borra y reinserta** las tablas académicas en cada corrida, por lo que `Curso` contiene **solo el término actual**.
- **En el modelo frontend:** `ClassOption` ya tiene `seatsAvailable` y `seatsMaximum` (y `nrc` como string).
- **En el snapshot guardado:** El `schedule_json` del favorito contiene los cupos **al momento de guardar**, no los actuales.

### 2.4 Diseño Propuesto

#### Backend

**Nuevo endpoint: `GET /api/favorites/status?nrcs=12345,67890,11111`**

- Recibe una lista de NRCs (comma-separated). Se **parsean a entero** (el NRC es entero en BD; los NRC no numéricos se descartan).
- Consulta `CuposDisponibles` y `CuposTotales` actuales de cada NRC en la tabla `Curso`.
- Retorna un mapa `{ nrc: { available: int, total: int } }` (las claves son strings, como en JSON). Los NRC que no existan en `Curso` se omiten del mapa → el frontend los trata como `eliminated`.
- Requiere sesión activa (cookie `session_id`); sigue el patrón de `favorite_routes.py` (`get_authenticated_user` + `run_in_threadpool`).
- **Solo tiene sentido para el término actual** (ver §2.6); el frontend no lo invoca para términos pasados.

```json
// Response
{
  "12345": { "available": 15, "total": 30 },
  "67890": { "available": 0, "total": 25 },
  "11111": { "available": 3, "total": 40 }
}
```

**Alternativa evaluada y descartada:** Enriquecer el `GET /api/favorites` con cupos actuales. Se descartó porque mezcla responsabilidades (persistencia vs estado en tiempo real) y porque el endpoint de status se puede reutilizar fuera de favoritos.

#### Frontend

1. **Enum `CourseStatus`** en `class_option.dart` o archivo nuevo:
   ```dart
   enum CourseStatus { safe, caution, atRisk, eliminated }
   ```

2. **Función `computeStatus(available, total) → CourseStatus`** que aplica los umbrales.

3. **`FavoritesScreen`:** Al seleccionar un horario **del término actual**, llama al endpoint de status con los NRCs del horario y obtiene los cupos actuales. Para términos pasados no se invoca (ver §2.6).

4. **Grilla de favoritos:** Coloreo alterno por `CourseStatus` en `buildSchedulePreview`. Se añade un parámetro **opcional** `colorResolver` (`Color Function(ClassOption)?`): si se pasa, se usa; si no, se mantiene el coloreo por materia (`subjectColors[subjectName]`). Esto preserva la compatibilidad con todos los usos actuales de `ScheduleGridWidget` (generación, mobile, previews del sidebar). En modo estado se mantiene el texto con el nombre de la materia (solo cambia el color de fondo).

5. **Leyenda de colores:** Pequeña leyenda debajo del título "Opción A" que explique qué significa cada color. Solo visible en modo estado.

6. **Toggle de modo de color (materia ↔ estado):** Permite alternar entre coloreo por materia y por estado de cupos, para no perder la referencia visual de qué materia es cada bloque. **Deshabilitado** (gris + tooltip "Estado de cupos disponible solo para el periodo actual") cuando el término seleccionado no es el actual; en ese caso el coloreo se mantiene por materia.

#### Repositorio

Nueva función en `repository.py`. **Síncrona con psycopg** (igual que el resto del repositorio; las rutas la llaman con `run_in_threadpool`):
```python
def get_nrc_seats(nrcs: list[str]) -> dict:
    """Consulta cupos actuales de una lista de NRCs en la tabla Curso.

    Devuelve { nrc(str): {'available': int, 'total': int} }.
    Los NRC no numéricos se ignoran; los inexistentes en Curso no aparecen.
    """
    nrc_ints = [int(n) for n in nrcs if str(n).isdigit()]
    if not nrc_ints:
        return {}

    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT NRC, CuposDisponibles, CuposTotales FROM Curso WHERE NRC = ANY(%s)",
            (nrc_ints,),
        )
        return {
            str(nrc): {"available": disp, "total": total}
            for (nrc, disp, total) in cursor.fetchall()
        }
    finally:
        cursor.close()
        conn.close()
```

### 2.5 Consideraciones

- Los cupos se actualizan con la frecuencia del cron ETL (actualmente cada ciertas horas). No es tiempo real.
- Si un NRC del favorito ya no existe en `Curso` (e.g., sección eliminada de Banner), se trata como `eliminated`.
- El endpoint de status NO modifica datos; es solo lectura.

### 2.6 Restricción al término actual

La tabla `Curso` solo contiene el **término actual** (el ETL borra y reinserta en cada corrida). Esto tiene dos consecuencias para favoritos de **términos pasados**:

1. **Sin datos:** sus NRCs probablemente ya no están en `Curso` → todo aparecería como `eliminated` (falso).
2. **Datos engañosos:** Banner **reutiliza NRCs** entre términos. Un NRC de un favorito viejo puede coincidir con un curso **distinto** del término actual → el estado mostrado sería de otra materia.

**Decisión:** el estado visual de cupos aplica **únicamente cuando `selectedTerm == currentTerm`**. Para términos pasados:
- No se llama al endpoint de status.
- El toggle materia/estado queda deshabilitado (con tooltip explicativo).
- El coloreo se mantiene por materia (comportamiento de Fase 1).

Esto evita mostrar información falsa y mantiene útil la pantalla para periodos anteriores.

---

## 3. Fase 3: Notificaciones por Correo

### 3.1 Problema

El usuario no tiene forma de enterarse si un curso de su horario destacado pierde cupos o es eliminado, a menos que entre a la aplicación y lo revise manualmente.

### 3.2 Objetivo

Enviar un correo electrónico al usuario cuando uno o más cursos de sus horarios destacados cambian a estado **"En riesgo"** o **"Eliminado"**.

### 3.3 Diseño Propuesto

#### Job periódico (Cron)

Nuevo script: `backend/scripts/notificar_cambios.py`

Flujo:
1. Obtener todos los horarios destacados activos de todos los usuarios.
2. Para cada horario, extraer los NRCs del `schedule_json`.
3. Consultar cupos actuales de esos NRCs.
4. Comparar con el estado anterior (almacenado en una nueva columna o tabla).
5. Si hay transiciones relevantes (e.g., Seguro → En riesgo), generar notificación.
6. Enviar correo agrupando todos los cambios por usuario.
7. Registrar el estado actual para la siguiente comparación.

#### Modelo de datos

**Opción A — Columna en `horario_destacado`:**
```sql
ALTER TABLE horario_destacado
ADD COLUMN last_status_snapshot JSONB DEFAULT '{}';
-- Formato: { "nrc": "safe", "nrc2": "atRisk", ... }
```

**Opción B — Tabla separada `estado_curso_notificacion`:**
```sql
CREATE TABLE estado_curso_notificacion (
    id SERIAL PRIMARY KEY,
    horario_destacado_id INTEGER REFERENCES horario_destacado(id) ON DELETE CASCADE,
    nrc VARCHAR NOT NULL,
    previous_status VARCHAR NOT NULL,
    current_status VARCHAR NOT NULL,
    checked_at TIMESTAMP DEFAULT NOW()
);
```

> **Recomendación:** Opción A (columna JSONB) es más simple y suficiente. La opción B solo se justifica si se quiere mantener historial de cambios.

#### Servicio de correo

**Opciones evaluadas:**

| Servicio | Ventajas | Desventajas |
|----------|----------|-------------|
| **SMTP UTB** | Sin costo, dominio institucional | Requiere coordinación con IT UTB |
| **SendGrid (free tier)** | 100 emails/día gratis, API simple | Dependencia externa |
| **Amazon SES** | Barato a escala, alta deliverability | Requiere cuenta AWS |
| **Resend** | Developer-friendly, 100/día gratis | Relativamente nuevo |

> **Decisión pendiente:** Depende de la infraestructura disponible y el volumen esperado.

#### Plantilla de correo

```
Asunto: ⚠️ Cambios en tu horario destacado — [Opción A]

Hola [nombre],

Se detectaron cambios en los cupos de tu horario destacado "Opción A":

🔴 Administración de Empresas (NRC 12345) — EN RIESGO
   Cupos: 3 de 40 disponibles

⚫ Cálculo Integral (NRC 67890) — ELIMINADO
   Cupos: 0 de 25 disponibles

Te recomendamos revisar tus opciones en la aplicación.

— Generador de Horarios UTB
```

#### Rate limiting y throttling

- **No enviar más de 1 correo por usuario por hora** (evitar spam si hay fluctuaciones).
- **Agrupar cambios:** Si múltiples horarios del mismo usuario tienen cambios, enviar un solo correo.
- **No notificar transiciones menores** (e.g., Seguro → Precaución). Solo En riesgo y Eliminado.

#### Preferencias del usuario

Posible extensión futura (no en primera iteración):
- Toggle en la UI para activar/desactivar notificaciones.
- Nueva columna `notificaciones_activas BOOLEAN DEFAULT TRUE` en tabla `usuario`.

### 3.4 Integración con Docker

```yaml
# En docker-compose.yml, añadir al cron-updater existente
# o crear un nuevo servicio:
notification-checker:
  build:
    context: ./backend
    dockerfile: scripts.Dockerfile
  command: ["python", "-m", "scripts.notificar_cambios"]
  # Ejecutar cada 4 horas (configurable)
```

---

## 4. Plan de Implementación

### Fase 2 (Estado visual)

| Paso | Componente | Descripción |
|------|-----------|-------------|
| 1 | Backend | Función **síncrona** `get_nrc_seats(nrcs)` en `repository.py` (tabla `Curso`) |
| 2 | Backend | Endpoint `GET /api/favorites/status` en `favorite_routes.py` (auth + `run_in_threadpool`) |
| 3 | Frontend | Colores de estado en `constants.dart`; enum `CourseStatus` y `computeStatus` |
| 4 | Frontend | `getFavoritesStatus` en `api_service.dart` |
| 5 | Frontend | Cargar status al seleccionar horario **solo si término actual**; estado en `ScheduleProvider` (mapa cupos + `colorMode`) |
| 6 | Frontend | Parámetro opcional `colorResolver` en `buildSchedulePreview` (back-compat) |
| 7 | Frontend | Leyenda + toggle materia/estado (deshabilitado en periodos pasados) en `FavoritesScreen` |
| 8 | Docs | Actualizar `backend.md`, `frontend.md` |

### Fase 3 (Notificaciones)

| Paso | Componente | Descripción |
|------|-----------|-------------|
| 1 | Decisión | Elegir servicio de correo |
| 2 | Backend | Script `notificar_cambios.py` |
| 3 | Backend | Columna `last_status_snapshot` en `horario_destacado` |
| 4 | Backend | Template de correo |
| 5 | Backend | Rate limiting y agrupación |
| 6 | Infra | Integrar en Docker Compose |
| 7 | Docs | Actualizar documentación |

## 5. Riesgos y Mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Datos de cupos no actualizados | Documentar frecuencia del ETL; mostrar timestamp de última actualización |
| NRC eliminado de Banner | Tratar como `eliminated`, mostrar mensaje claro al usuario |
| Spam de correos por fluctuaciones | Throttling por usuario + solo notificar transiciones graves |
| Costo de servicio de email | Empezar con free tier, evaluar escala real |
| Rendimiento de consulta masiva de NRCs | `NRC` es PK de `Curso` (índice único ya existe); el `WHERE NRC = ANY(%s)` lo aprovecha |

## 6. Criterios de Aceptación

### Fase 2
1. Los bloques de la grilla de favoritos muestran colores según cupos actuales.
2. Se muestra leyenda explicativa de los colores.
3. Los cupos se consultan al backend, no se usan los del snapshot guardado.
4. El estado solo aplica al término actual: en periodos pasados el toggle queda deshabilitado y el coloreo se mantiene por materia.

### Fase 3
1. El usuario recibe correo cuando un curso pasa a "En riesgo" o "Eliminado".
2. No se envían más de 1 correo por hora por usuario.
3. El correo incluye detalles claros de qué cursos cambiaron y cuál es su estado actual.

## 7. Decisiones Pendientes

- [x] **Umbrales por estado (Fase 2):** confirmados los de §2.2 (>50% / 20–50% / <20% y >0 / 0). _(2026-06-14)_
- [x] **Estado en periodos pasados (Fase 2):** solo término actual; toggle deshabilitado en periodos anteriores. Ver §2.6. _(2026-06-14)_
- [x] **Toggle materia/estado (Fase 2):** incluido desde la primera iteración. _(2026-06-14)_
- [ ] Servicio de correo a utilizar (Fase 3).
- [ ] ¿Notificar también transición Precaución → En riesgo, o solo los graves? (Fase 3)
- [ ] ¿Toggle de notificaciones por usuario desde la primera iteración? (Fase 3)
