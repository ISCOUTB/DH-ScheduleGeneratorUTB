# RFC: Cursos personalizados

- Fecha: 2026-07-17
- Estado: Propuesta
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
- `inserter.py`: `INSERT INTO Materia ... ON CONFLICT (codigomateria, nombre) DO NOTHING`.
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

→ **Decisión:** `ON CONFLICT DO NOTHING`. Un renombre deja la fila vieja como descontinuada y crea una nueva. Se acepta que el catálogo acumule materias muertas. **No existe "actualizar el nombre".**

> Costo asumido: el catálogo crece semestre a semestre con nombres que ya nadie dicta. A cambio, nunca se fusionan dos materias distintas. Si algún día molesta, la limpieza es manual y con criterio humano, no automática.

## 4. Modelo

Un **curso personalizado** es una `ClassOption` declarada por el usuario, colgada de una materia del catálogo:

| Campo | Origen |
|---|---|
| materia (`código`, `nombre`) | elegida del catálogo (no se inventa) |
| `credits` | **de `Materia`**, no del usuario |
| bloques (día + inicio/fin) | los teclea el usuario — es el dato mínimo |
| `nrc` | opcional; si no lo sabe, se genera uno sintético |
| `professor`, `campus`, `type` | opcionales |

Persisten **por usuario** (no por sesión): son "el curso que ya matriculé", tienen que sobrevivir al reload.

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

### 6.2 Panel de gestión — la biblioteca

Lista **todos** los cursos personalizados del usuario, agrupados por materia, **estén o no seleccionadas**. Por cada uno: switch, editar, borrar. Es donde se **crean** (se elige la materia del catálogo → se teclean los bloques). Resuelve de raíz el caso *"quiero ver / gestionar los cursos aunque la materia no esté en mi lista de trabajo"*.

### 6.3 Entradas al panel (decisión del equipo)

| Entrada | Dónde | Intención |
|---|---|---|
| **Aviso en el header** | Cabecera de "Materias Seleccionadas": *"N cursos personalizados"*, **clickeable** | Ver / gestionar |
| **"Agregar curso"** | Al lado de `+ Agregar materia` (`subjects_panel.dart:235-237`) | Crear uno nuevo |
| **Speed dial (móvil)** | Ítem nuevo en `SpeedDialMenu` (`speed_dial_menu.dart`), junto a Buscar/Filtrar/Destacados | Ver / gestionar |

Las tres abren el **mismo** panel; "Agregar curso" lo abre listo para crear. Con esto la feature es descubrible sin sumar un cuarto botón grande arriba (en escritorio) y queda accesible donde el usuario móvil ya busca acciones.

**No** se usa un botón `+` junto al `−` de la materia: `+`/`−` se leen como pareja (agregar/quitar **la materia**), y ahí el `+` significaría otra cosa.

### 6.4 Crear un curso desde el panel: ¿toca la lista de trabajo?

Crear un curso en el panel **solo lo persiste**; no mete la materia en "Materias Seleccionadas". Consecuencia: se puede crear un curso y que **no cambie ningún horario** hasta que la materia esté en la lista con el switch activo.

Eso puede confundir (*"lo agregué y no pasó nada"*). **A decidir en implementación** — opciones:
- **(a)** Al crear, si la materia no está seleccionada, ofrecer *"¿Agregarla a tu lista para usar este curso ahora?"*.
- **(b)** Auto-agregarla con el switch activo (más directo, menos control).
- **(c)** Dejarlo explícito y avisar en el panel: *"Esta materia no está en tu lista; agrégala para generar con este curso."*

Recomendación: **(c)** por defecto (nada implícito) + un botón *"Agregar a mi lista"* ahí mismo = (a) sin modal. El auto-agregado (b) sorprende.

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

**Fase 1 — el prerequisito:** `Materia` como catálogo (§3) + partir la lista de búsqueda. Sin esto no hay dónde colgar nada. Es independiente y desplegable solo.

**Fase 2 — el modelo:** tabla, endpoints CRUD, y el generador aceptando dominios personalizados (§5).

**Fase 3 — la UI:** anidado + switch en la lista de trabajo (§6.1); panel de gestión con crear/editar/borrar + formulario de bloques (§6.2); las tres entradas —aviso clickeable en el header, "Agregar curso", ítem en el speed dial móvil— (§6.3); y excluir los cursos personalizados del aviso de destacados (§7).

## 10. Descartado (con razón)

| Idea | Por qué no |
|---|---|
| Dejar inventar la materia | El usuario tecleaba los créditos → el tope de 20 se vuelve ficción suya. Con `Materia` real salen de la BD. |
| Actualizar el nombre cuando el código coincide | Fusionaría materias legítimamente distintas (`CBASE03A`, `RULEI02B`). Un renombre es indistinguible de una variante nueva desde los datos (§3.1). |
| **Segunda lista de trabajo** de cursos personalizados (que reemplace el anidado) | El curso es una restricción sobre una materia, no una entidad libre; dos listas de trabajo obligan a reconciliar cuál manda (§6.1). El panel de gestión (§6.2) **no** es una segunda lista de trabajo: es la biblioteca, con otro rol. |
| Combinar oferta real + personalizada | Ignoraría la decisión del usuario: el punto es fijar ESE curso, y combinarlo con la oferta lo des-fija. El switch permite alternar (§5). |
| Botón `+` junto al `−` de la materia | `+`/`−` se leen como pareja sobre **la materia**; el `+` significaría otra cosa (§6.3). |
| Auto-agregar la materia al crear un curso | Sorprende (*"¿por qué apareció Cálculo?"*). Se prefiere avisar + botón explícito (§6.4). |
