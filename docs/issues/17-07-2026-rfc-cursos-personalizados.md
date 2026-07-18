# RFC: Cursos personalizados

- Fecha: 2026-07-17
- Estado: **Implementada** (Fases 1–3). Ver §11 para lo que cambió respecto a la propuesta.
- Alcance: BD (persistencia de `Materia`, tabla nueva), ETL, Backend (generador, endpoints), Frontend (panel de materias)

## 1. Contexto

La oferta que la app consume es **volátil**, por dos causas según el momento del semestre:

- **Antes de matrícula (planeación):** la universidad libera los cursos con anticipación para que la gente planifique, y **los edita constantemente** — agrega, quita y ajusta secciones, y les cambia el NRC. Esta es la causa **hoy**: la matrícula aún no empieza.
- **Durante matrícula:** además, Banner **saca las secciones cuando se llenan**.

Por cualquiera de las dos vías, un curso que el estudiante quiere fijar puede **no estar** en la respuesta actual de Banner. Caso típico: ya tiene decidido (o matriculado) un curso y quiere que el generador arme el resto del horario a su alrededor, pero ese curso —por edición de la oferta o por haberse llenado— ya no aparece.

No es hipotético. En el periodo actual —donde la matrícula **aún no empieza**, así que esto es puro cambio de oferta— **69 favoritos** tienen al menos una clase cuyo NRC ya no está en `Curso` (ver `feat(favorites): avisar qué horarios destacados tienen clases con problemas`).

**Objetivo:** permitir que el usuario declare un curso que él sabe que tiene (o que quiere fijar) y que el generador arme el resto del horario alrededor.

### 1.1 Por qué no basta con `unavailable_slots`

Ya existe el filtro de horas no disponibles: se puede bloquear "martes 8-10" y el generador planea alrededor. Un curso personalizado agrega dos cosas que el filtro no da:

- **Cuenta créditos** contra el tope de 20.
- **Aparece en el horario** con su materia, NRC y profesor → el estudiante ve su semestre **completo** en la grilla, el PDF y el Excel, no un hueco.

Si el único objetivo fuera tapar horas, esta RFC no haría falta.

## 2. Restricciones del sistema real (verificadas contra el código)

1. **`Materia` hoy es derivada de la oferta, no un catálogo.** Está en `ACADEMIC_TABLES` (`backup.py:10-15`) y cada ETL hace `DELETE FROM Materia` (`:35`); `inserter.py:9` reinserta con un `INSERT` pelado, **sin `ON CONFLICT`**. Una materia que pierde todos sus cursos **desaparece**.

2. **La lista de búsqueda saldría contaminada.** `get_all_subjects_summary()` hace `SELECT ... FROM Materia` **sin join a `Curso`** (`repository.py:275`). El día que `Materia` persista, las materias sin oferta aparecen solas en el buscador.

3. **El generador solo lee de `Curso`.** `get_combinations_for_subjects` arma `combinations_per_subject` desde la BD (`repository.py:90-116`). Un curso personalizado no está ahí.

4. **La identidad de una materia es el par `(código, nombre)`** — ver `docs/modelo_datos.md`. Es la llave con la que viajan los filtros.

## 3. El prerequisito: `Materia` pasa a ser catálogo

Para que el usuario elija una materia **existente** (y no invente una), `Materia` debe sobrevivir aunque pierda sus cursos.

**Por qué importa que sea existente:** no es limpieza — es que **la materia carga los créditos**. Si el usuario inventa una materia, teclea los créditos, y el tope de 20 pasa a ser ficción controlada por él. Con una `Materia` real, `creditos` sale de la BD.

**Cambios:**
- Sacar `Materia` de `ACADEMIC_TABLES` (`backup.py`). `Clase`, `Curso` y `Profesor` se siguen limpiando: esos **sí** son la oferta del periodo.
- `inserter.py`: `INSERT INTO Materia ... ON CONFLICT (codigomateria, nombre) DO UPDATE SET Creditos = EXCLUDED.Creditos`. (Se implementó `DO UPDATE` en vez de `DO NOTHING` — misma semántica de renombres, pero refresca los créditos si la U los ajusta; ver §3.1.)
- Actualizar `docs/issues/29-03-2026-politica-persistencia-etl.md`: `Materia` deja de ser derivada.
- Partir la lista de búsqueda en dos: **con oferta** (buscador normal, `JOIN Curso`) y **todas** (selector de curso personalizado).

### 3.1 Los renombres: lo que NO se puede hacer

Es tentador decir *"si el código es el mismo y el nombre cambió, actualizo el nombre"*. **No se puede**, y hay datos que lo prueban:

| Código | Nombres |
|---|---|
| `CBASE03A` | *Estadística I (Cs. Sociales)* · *(Ciencia Política)* · *(Derecho)* |
| `RULEI02B` | *Inglés Ii* · *Inglés Ii - Derecho* |

Ahí el mismo código hospeda materias **legítimamente distintas**. Aplicar "mismo código → actualizo el nombre" las **fusionaría**, destruyendo una.

Y el fondo: **desde los datos, un renombre es indistinguible de una variante nueva.** Banner no manda "esto era X y ahora es Y"; solo se ve un código con dos nombres. Por eso la PK es compuesta.

→ **Decisión:** `ON CONFLICT (codigomateria, nombre) DO UPDATE SET Creditos`. El conflicto es sobre el **par completo**, así que un renombre (código igual, nombre distinto) **no** hace conflicto: deja la fila vieja como descontinuada y crea una nueva. El `DO UPDATE` solo actúa cuando reaparece el **mismo par** exacto, y lo único que toca es `Creditos` (por si la U los reajusta). **No existe "actualizar el nombre".**

> Costo asumido: el catálogo crece semestre a semestre con nombres que ya nadie dicta. A cambio, nunca se fusionan dos materias distintas. Si algún día molesta, la limpieza es manual y con criterio humano, no automática.

## 4. Modelo

Un **curso personalizado** es una `ClassOption` declarada por el usuario, colgada de una materia del catálogo:

| Campo | Origen |
|---|---|
| materia (`código`, `nombre`) | elegida del catálogo (no se inventa) |
| `credits` | **de `Materia`**, no del usuario |
| bloques (día + inicio/fin) | los marca el usuario — es el dato mínimo. Convención `:50`: se marcan **horas**; una clase de 1h que empieza a las 9 termina 9:50; una de 2h que empieza a las 8 termina 9:50. El usuario no teclea minutos; horas contiguas del mismo día se funden en un bloque. |
| `nrc` | opcional; si no lo sabe, se genera uno sintético `CP{id}`. Si lo teclea y **ya existe en `Curso`**, se **bloquea** (*"Ese NRC ya existe en la materia X. Usa otro."*) — no hay opción de forzar. |
| `professor`, `campus`, `type` | opcionales |

Persisten **por usuario** (no por sesión): son "el curso que ya matriculé", tienen que sobrevivir al reload.

El prefijo `CP` del NRC sintético también sirve para **excluir** estos cursos del aviso "fuera de la oferta" de destacados (§7): un NRC que empieza con `CP` no se busca en `Curso`.

## 5. Semántica de generación

**Regla:** para una materia dada,
- si **≥1** curso personalizado está **activo** → su dominio es **exactamente esos**;
- si **ninguno** está activo → su dominio es **la oferta real**.

O sea: **la oferta ficticia reemplaza a la real, no se suma.** Razón: el punto de un curso personalizado es **fijar ese curso** (el que el estudiante decidió o matriculó). Si se combinara con la oferta real, el generador produciría horarios alternativos con otras secciones de esa materia — ignorando la decisión que el usuario acaba de fijar. Combinar des-fija.

Dos cursos personalizados activos = "esta materia oferta estos dos", y el backtracking los trata como alternativas. Encaja sin casos especiales: es una materia con dominio de tamaño N.

> **Costo asumido:** no se puede ver "oferta real + la mía" en una sola generación. Quien quiera comparar, alterna el switch. Se acepta a cambio de que el modelo sea predecible.

### 5.1 Casos derivados

| Situación | Resultado |
|---|---|
| Switch activo + materia sin oferta | Funciona: el dominio es el curso personalizado. **Este es el caso de uso principal.** |
| Switch inactivo + materia sin oferta | Dominio vacío → el diagnóstico dice *"Cálculo no tiene cursos en la oferta de este periodo"*. Correcto y gratis (ver RFC de diagnóstico, §6.1). |
| Curso personalizado que choca | Es una materia con dominio 1 → cae en **U2** del diagnóstico → *"Tu curso X se cruza con Cálculo"*. Sin código nuevo. |

## 6. UI

Dos superficies con roles distintos: la **lista de trabajo** (dónde se ven y togglean los cursos de las materias seleccionadas) y el **panel de gestión** (la biblioteca: todos los cursos personalizados, se seleccione o no la materia, y dónde se crean/editan/borran).

### 6.1 Lista de trabajo — anidados bajo su materia

Los cursos personalizados de una materia **seleccionada** se muestran anidados bajo ella, cada uno con su switch:

```
Materias Seleccionadas
├── ● Cálculo                                    −
│     └── [x] NRC 1234 · Mar 8-10                    ← switch por curso
│     └── [ ] NRC 5678 · Jue 14-16
└── ● Física                                     −
```

**Por qué anidados y no una lista suelta:** un curso personalizado **no es una entidad libre, es una restricción sobre una materia**. Anidarlo hace ese vínculo obvio y hace que el switch signifique algo concreto: *"usa el mío"* vs *"usa los ofertados"*. En una lista aparte el switch quedaría ambiguo, y obligaría a reconciliar mentalmente dos listas (*"¿Cálculo está en las dos? ¿cuál manda?"*).

Los anidados se pueden **expandir/contraer** con un chevron en la tarjeta de la materia (solo aparece si la materia tiene cursos personalizados). En este panel **no** se muestra el código de la materia — el código queda solo dentro del detalle.

### 6.2 Panel de gestión — la biblioteca

Lista **todos** los cursos personalizados del usuario, agrupados por materia, **estén o no seleccionadas**. Por cada uno: switch, editar, borrar. Es donde se **crean** (se elige la materia del catálogo → se marcan los bloques). Resuelve de raíz el caso *"quiero ver / gestionar los cursos aunque la materia no esté en mi lista de trabajo"*.

**Crear/editar es un paso a paso (wizard):** 1) materia (autocompletar sobre el catálogo completo), 2) horario, 3) datos opcionales (profesor, NRC con validación en vivo). Primero se fija la materia, luego la franja, y al final se complementa.

**Selección de horario, responsive:**
- **Escritorio:** grilla interactiva (días × horas) que se pinta con clic o arrastre; el modo marcar/borrar lo fija la primera celda.
- **Móvil:** la grilla queda con celdas diminutas, así que en pantalla angosta (`< 600px`) se usa un formulario **"Agregar bloque"** (Día + De/A). El dropdown "A" solo ofrece horas `>= "De"` (etiquetadas `H:50`); los bloques agregados se listan como chips con ✕. Ambos escriben sobre la misma estructura de celdas, así que el resto (resumen, edición, generación) no cambia.

### 6.3 Entradas al panel (decisión del equipo)

| Entrada | Dónde | Intención |
|---|---|---|
| **Aviso en el header** | Cabecera del panel, al **extremo opuesto** de "2026-2P": *"N cursos personalizados"*, **clickeable** | Ver / gestionar |
| **"Crear curso"** | Al **lado opuesto** de `+ Agregar materia` (extremos de la fila, no agrupados) | Abre el panel de gestión |
| **Speed dial (móvil)** | Ítem nuevo en `SpeedDialMenu` (`speed_dial_menu.dart`), junto a Buscar/Filtrar/Destacados | Ver / gestionar |

Las tres abren el **mismo** panel de gestión; desde ahí, el "+ Agregar curso" del panel abre el wizard de creación. (En la propuesta el botón se llamaba "Agregar curso" y abría el wizard directo; se cambió a "Crear curso" → panel para que las tres entradas sean consistentes.) Con esto la feature es descubrible sin sumar un cuarto botón grande arriba (en escritorio) y queda accesible donde el usuario móvil ya busca acciones.

**No** se usa un botón `+` junto al `−` de la materia: `+`/`−` se leen como pareja (agregar/quitar **la materia**), y ahí el `+` significaría otra cosa.

### 6.4 Crear un curso desde el panel: ¿toca la lista de trabajo?

Crear un curso **sí** mete la materia en "Materias Seleccionadas" si no estaba, con el switch activo, para que el curso entre a la generación **enseguida**.

**Decisión final (revierte la recomendación de la propuesta):** se optó por la opción **(b) auto-agregar**. La propuesta recomendaba **(c)** (no tocar la lista, solo avisar) por miedo a que auto-agregar sorprendiera; en la práctica pesó más el *"lo creé y no pasó nada"*: el usuario que se molesta en crear un curso lo quiere usando, no esperando un segundo paso. El botón *"Agregar a mi lista"* + el aviso de (c) **se conservan** en el panel para los casos donde la materia quedó fuera (cursos viejos, o cuando `addSubject` se bloquea por un conflicto de horario del estado actual).

Opciones que se consideraron:
- **(a)** Al crear, si la materia no está seleccionada, ofrecer *"¿Agregarla a tu lista para usar este curso ahora?"* (modal).
- **(b)** Auto-agregarla con el switch activo. ← **elegida**
- **(c)** Dejarlo explícito y avisar en el panel. ← conservada como respaldo, no como principal.

### 6.5 Quitar la materia no borra el curso

Los cursos personalizados se guardan por **usuario + materia**, independientes de la lista de trabajo. Quitar la materia de "Materias Seleccionadas" la saca de la generación pero **no destruye el curso**: sigue en el panel, y al volver a agregar la materia reaparece anidado con su switch como se dejó.

Eso resuelve el caso *"no quiero borrarlo pero tampoco generar con esa materia ahora"*.

> **Comunicación:** que el curso no se borra al quitar la materia hay que **decirlo**, o la gente no se atreverá. La infraestructura ya existe: `ImportantNoticeDialog` + `has_seen_important_notice` en localStorage (`home_screen.dart:102-111`), reusable para un aviso de novedades.

## 7. Interacción con lo existente

| Qué | Impacto |
|---|---|
| **Aviso de destacados** | ⚠️ **Falso positivo.** `issuesForSchedule` marca "fuera de la oferta" cuando el NRC no está en `Curso` — que es **exactamente** la condición de un curso personalizado. Hay que excluirlos o marcarían algo que está bien a propósito. |
| **Diagnóstico** | Funciona solo (§5.1). |
| **Créditos** | Cuentan contra el tope de 20; salen de `Materia`, no del usuario. |
| **Favoritos** | Un curso personalizado dentro de un favorito serializa igual (es una `ClassOption` en `schedule_json`). |
| **Filtros** | Un curso personalizado no tiene profesor real ni NRC de la oferta. Los filtros de profesor/NRC sobre esa materia **no aplican** cuando el switch está activo (su dominio ya está fijado por el usuario). |

## 8. Esquema y contrato

```sql
CREATE TABLE IF NOT EXISTS public.curso_personalizado (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER NOT NULL REFERENCES public.usuario(id),
    codigomateria VARCHAR NOT NULL,
    nombremateria VARCHAR NOT NULL,
    nrc VARCHAR,                      -- opcional; sintético si el usuario no lo sabe
    tipo VARCHAR,
    profesor VARCHAR,
    campus VARCHAR,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    bloques JSONB NOT NULL,           -- [{"day": "Martes", "time": "08:00 - 09:50"}]
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (codigomateria, nombremateria)
        REFERENCES public.materia(codigomateria, nombre)
);
```

La FK al par `(codigomateria, nombre)` es lo que **garantiza** que la materia exista — y es la razón por la que `Materia` tiene que persistir (§3): sin eso, la FK se rompería en el próximo ETL.

`curso_personalizado` va en `PRESERVED_APP_TABLES` (`backup.py:18-22`): es dato de usuario, no oferta.

**Generación:** el frontend ya manda `subjects` y `filters`. Los cursos personalizados **activos** viajan en el request (el backend los inyecta como el dominio de esa materia), o se leen de la tabla por sesión. A decidir en implementación; mandarlos en el payload es más simple y no obliga al generador a conocer al usuario.

## 9. Fases

**Fase 1 — el prerequisito ✅:** `Materia` como catálogo (§3) + partir la lista de búsqueda. Sin esto no hay dónde colgar nada. Es independiente y desplegable solo.

**Fase 2 — el modelo ✅:** tabla, endpoints CRUD, y el generador aceptando dominios personalizados (§5).

**Fase 3 — la UI ✅:** anidado + switch en la lista de trabajo (§6.1); panel de gestión con crear/editar/borrar + wizard de bloques (§6.2); las tres entradas —aviso clickeable en el header, "Crear curso", ítem en el speed dial móvil— (§6.3); y excluir los cursos personalizados del aviso de destacados (§7).

## 10. Descartado (con razón)

| Idea | Por qué no |
|---|---|
| Dejar inventar la materia | El usuario tecleaba los créditos → el tope de 20 se vuelve ficción suya. Con `Materia` real salen de la BD. |
| Actualizar el nombre cuando el código coincide | Fusionaría materias legítimamente distintas (`CBASE03A`, `RULEI02B`). Un renombre es indistinguible de una variante nueva desde los datos (§3.1). |
| **Segunda lista de trabajo** de cursos personalizados (que reemplace el anidado) | El curso es una restricción sobre una materia, no una entidad libre; dos listas de trabajo obligan a reconciliar cuál manda (§6.1). El panel de gestión (§6.2) **no** es una segunda lista de trabajo: es la biblioteca, con otro rol. |
| Combinar oferta real + personalizada | Ignoraría la decisión del usuario: el punto es fijar ESE curso, y combinarlo con la oferta lo des-fija. El switch permite alternar (§5). |
| Botón `+` junto al `−` de la materia | `+`/`−` se leen como pareja sobre **la materia**; el `+` significaría otra cosa (§6.3). |
| Forzar un NRC que ya existe en la oferta | Se bloquea sin opción de forzar: un NRC duplicado confundiría el horario/PDF. El usuario teclea otro o lo deja vacío (sintético `CP{id}`) (§4). |

> El "auto-agregar la materia al crear" que aquí estaba descartado **se revirtió y sí se implementó** — ver §6.4 para el razonamiento.

## 11. Estado de implementación

Lo entregado y en qué archivo vive. Los puntos marcan dónde la implementación **divergió** de la propuesta.

### Backend / BD
| Pieza | Archivo |
|---|---|
| `Materia` fuera de `ACADEMIC_TABLES`; `curso_personalizado` en `PRESERVED_APP_TABLES` | `backend/scripts/backup.py` |
| `INSERT ... ON CONFLICT DO UPDATE Creditos` (⚠ era `DO NOTHING`) | `backend/scripts/inserter.py` |
| Tabla `curso_personalizado` (+ migración idempotente) | `backend/init.sql`, `backend/scripts/migrar_esquema.py` |
| Catálogo completo vs. solo-oferta; CRUD; `get_nrc_subject` (⚠ NRC hard-block) | `backend/app/db/repository.py` |
| Endpoints CRUD, `GET /nrc-check`, 409 si el NRC ya existe (⚠) | `backend/app/routes/custom_course_routes.py` |
| `CustomCourseInput`, `customCourses` en el request | `backend/app/models.py` |
| `/api/subjects-catalog`; inyección del dominio personalizado en la generación (§5) | `backend/app/main.py` |

### Frontend
| Pieza | Archivo |
|---|---|
| Modelo `CustomCourse` (`subjectKey`, `toGenerationJson`) | `frontend/lib/models/custom_course.dart` |
| Excluir `CP*` del aviso de destacados (§7) | `frontend/lib/models/course_status.dart` |
| Estado/CRUD; **auto-agregar materia al crear** (⚠ §6.4) | `frontend/lib/providers/schedule_provider.dart` |
| API: catálogo, CRUD, `checkNrcTaken` | `frontend/lib/services/api_service.dart` |
| Wizard 3 pasos; grilla (desktop) + **formulario Día/De-A (móvil, ⚠ §6.2)** | `frontend/lib/widgets/custom_course/custom_course_wizard.dart` |
| Panel de gestión (biblioteca) | `frontend/lib/widgets/custom_course/custom_courses_panel.dart` |
| Anidado + switch + **expand/collapse**, sin código (⚠ §6.1); botón **"Crear curso"** al extremo (⚠ §6.3) | `frontend/lib/widgets/subjects_panel.dart` |
| Entrada speed dial móvil (§6.3) | `frontend/lib/widgets/layout/speed_dial_menu.dart` |
| Carga inicial; wiring de las entradas | `frontend/lib/screens/home_screen.dart` |

### Divergencias respecto a la propuesta
1. **`ON CONFLICT DO UPDATE Creditos`** en vez de `DO NOTHING` (§3, §3.1) — refresca créditos sin cambiar la semántica de renombres.
2. **Auto-agregar la materia al crear** (§6.4) — se eligió (b), no la (c) recomendada. El aviso + botón de (c) quedan como respaldo.
3. **NRC hard-block** (§4) — si el NRC ya existe en `Curso`, se bloquea sin forzar.
4. **Selector de horario móvil** (§6.2) — formulario "Agregar bloque" bajo `600px`; la grilla clic/arrastre queda solo para escritorio.
5. **Botón "Crear curso"** (§6.3) — renombrado y abre el panel (no el wizard directo); ubicado al extremo opuesto de "Agregar materia".

### Nota de despliegue (ETL)
`backup.py` y el esquema `curso_personalizado` **deben desplegarse juntos**. Si el contenedor `cron-updater` corre un `backup.py` viejo (con `Materia` aún en `ACADEMIC_TABLES`) contra una BD que ya tiene la tabla nueva, el `DELETE FROM Materia` rompe la FK `curso_personalizado_...fkey` y el ETL aborta (la transacción hace rollback, sin pérdida de datos, pero no actualiza la oferta). En local: `docker compose up -d --build backend cron-updater`.

> **Trampa del seeder (2026-07-18):** el mismo crash reapareció aunque `cron-updater` estaba fresco, porque el **poblado** corre en un servicio **distinto**, `initial-data` (mismo `scripts.Dockerfile`), y `dev-frontend.ps1/.sh` lo lanzaba con `docker compose run --rm initial-data` **sin `--build`**. Esa imagen quedaba stale (con `backup.py` viejo) y borraba `materia`. **Fix:** el seed ahora usa `run --rm --build initial-data`. No era el volumen de la BD ni `--seed`; era la imagen de `initial-data` sin reconstruir. Regla general: **cualquier** servicio del `scripts.Dockerfile` que corra el ETL (`cron-updater`, `initial-data`) debe reconstruirse con el código actual.

## 12. Iteración de UI y correcciones (2026-07-18, post-commit `4df7293`)

Ronda de pulido y arreglos sobre lo ya implementado. Agrupado por tema.

### 12.1 Diferenciar el curso personalizado en las grillas (`isCustom`)
Antes no se distinguía visualmente un curso personalizado del resto en el horario. Se agregó un flag **`isCustom`** de punta a punta:
- Backend: `ClassOption.is_custom` (alias `isCustom`) en `models.py`; `_custom_option_group` en `main.py` lo pone `True`.
- Frontend: `ClassOption.isCustom` (`class_option.dart`), serializado en `toJson` para que **sobreviva en favoritos**.
- Render: en la grilla de resultados/preview (`schedule_preview_card.dart`) y en el detalle (`schedule_overview_widget.dart`) el bloque personalizado se pinta con **relleno translúcido + borde de su color** (conserva el color que identifica la materia), y texto en el color oscurecido. Así se distingue también en **horarios destacados**.

### 12.2 Detalle y descargas: qué se muestra de un curso personalizado
Un curso personalizado no tiene campus ni cupos "oficiales". En el **detalle** (`schedule_overview_widget.dart`) y en las **descargas PDF/Excel** (`schedule_export.dart`):
- **Sin campus** y **sin cupos**.
- **Profesor** solo si el estudiante lo puso; **NRC** solo si lo puso (el sintético `CP{id}` no se muestra).
- Donde iría el profesor se rotula **"Curso Personalizado"** (y como "Tipo" en las tablas; en la grilla del PDF/Excel el bloque dice "Curso Personalizado").
- El backend ahora manda `professor=""` (no `"Personalizado"`) cuando no hay profesor. Como blindaje, el frontend además trata el literal `"Personalizado"` como "sin profesor" (por si corre contra un backend sin redeploy).
- En el detalle, un curso personalizado **nunca** se marca en rojo "sin cupos/eliminado".

### 12.3 Estado/alertas: excluir por `isCustom`, no por prefijo `CP` (bug)
La exclusión de cursos personalizados del modo "Estado" y del aviso de destacados se hacía por `nrc.startsWith('CP')`. Al permitir **NRC real** del usuario (4 dígitos), esos cursos volvían a marcarse **"Eliminado"** (gris) y disparaban la alerta ⚠. **Fix** en `course_status.dart` y `schedule_overview_widget.dart`: excluir por **`isCustom`** (se deja el `CP` también, para favoritos viejos sin el flag). `statusForClass` devuelve `safe` para un curso personalizado.

### 12.4 Filtros vacíos para materias agregadas por curso personalizado (bug)
`addSubjectFromCustom` agregaba la materia con `classOptions: []`, así que los filtros de **NRC/profesor** no tenían opciones (a diferencia de agregarla por "Buscar materia", que trae la oferta). **Fix** (`schedule_provider.dart`): ahora `addSubjectFromCustom` es `async` y **trae la oferta real** con `getSubjectDetails` (fallback a vacío si la materia no tiene oferta). Los llamadores (`createCustomCourse`, "Agregar a mi lista") pasan a `await`.

### 12.5 Wizard: pulido de formulario
- **Aviso azul** de "para qué sirve" movido del wizard al **panel de gestión** (`custom_courses_panel.dart`), estilo "Buscar Materia".
- Campos marcados **"(opcional)"** (Nombre, Profesor, NRC).
- **Nombre del curso:** el default ya no se escribe en el campo. El label dice **"Nombre del curso (Por defecto: Curso A)"** y el placeholder es el default (`Curso A`); el esquema pasó de "Curso Creado A" a **"Curso A"** (siguiente letra libre). Se aplica al guardar si queda vacío.
- **NRC:** solo dígitos, máx 4 (`inputFormatters`); si mete 1–3 dígitos → error y bloqueo; solo consulta al backend con 4. Ícono **ℹ️ con tooltip** (3 líneas) explicando que el NRC es único por periodo: si ya existe, ese curso está en la oferta (o te equivocaste al digitar).
- Labels de campo **más oscuros** (`#374151`, negrita) para que resalten más que el texto interno.

### 12.6 Grilla de horario (paso 2): selección por rango + arreglo del arrastre
- Antes el arrastre fijaba el modo (marcar/borrar) en la primera celda y no se podía deshacer arrastrando de vuelta. Ahora es **selección por rango**: la celda ancla y la del cursor definen un rectángulo; **arrastrar de vuelta lo encoge** (corrige el sobrepaso). El modo lo fija el ancla (vacía → marca; llena → borra). Reaplica sobre un snapshot tomado al `pointer-down`.
- El arrastre **respondía con retraso** (~1 s) porque `GestureDetector` (pan) competía en la arena de gestos con el tap y el scroll. **Fix:** se cambió a **`Listener`** (eventos de puntero crudos, sin arena) → respuesta inmediata.

### 12.7 Botones "Agregar materia" / "Crear curso"
Van **contiguos en una fila, centrados como grupo** (`Row` dentro de `Center`+`FittedBox(scaleDown)`): muestran el texto completo y, si no cupieran, escalan el grupo en vez de cortar la palabra o apilarse.

### 12.8 Archivos tocados en esta ronda
`backend/app/models.py`, `backend/app/main.py`, `frontend/lib/models/class_option.dart`, `frontend/lib/models/course_status.dart`, `frontend/lib/widgets/schedule_preview_card.dart`, `frontend/lib/widgets/schedule_overview_widget.dart`, `frontend/lib/services/schedule_export.dart`, `frontend/lib/widgets/custom_course/custom_course_wizard.dart`, `frontend/lib/widgets/custom_course/custom_courses_panel.dart`, `frontend/lib/widgets/subjects_panel.dart`, `frontend/lib/providers/schedule_provider.dart`.

> Nota de datos: los favoritos guardados **antes** de `isCustom` no traen el flag → se ven como curso normal. Solo aplica a horarios nuevos. Sin migración de datos (no vale la pena).
