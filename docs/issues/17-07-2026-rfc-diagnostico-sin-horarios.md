# RFC: Diagnóstico de "no hay horarios" — decir qué se cruza con qué

- Fecha: 2026-07-17
- Estado: Propuesta
- Alcance: Backend (generador, endpoint), Frontend (mensajes, guarda de agregar materia)

## 1. Contexto

Cuando el generador devuelve 0 horarios, la app muestra un mensaje genérico que **adivina** la causa (`schedule_provider.dart:299-307`):

- Con filtros → *"No se encontraron horarios con los filtros aplicados… posiblemente se trate de un cruce de horario."*
- Sin filtros → *"No se pueden generar horarios con estas materias. Puede haber cruces o incompatibilidades."*

Los usuarios piden lo obvio: **qué materia se cruza con cuál**, para saber qué quitar.

Esta RFC enumera **todas** las causas posibles de un resultado vacío y define un diagnóstico que las distingue sin mentir.

## 2. Restricciones del sistema real (verificadas contra el código)

1. **El generador no es incremental.** `find_valid_schedules` es stateless: rehace el backtracking desde cero con la lista completa en cada llamada (`main.py:94`). Lo incremental es solo que el front re-llama en cada `addSubject` (`schedule_provider.dart:186`).

2. **La respuesta del generador no sirve para diagnosticar:**
   - **Fusión**: los horarios idénticos por firma se fusionan y se les **inyectan NRCs de otros horarios** (`schedule_generator.py:181-202`). Un "horario" de la respuesta no es una combinación limpia.
   - **Truncado**: en móvil se cortan a `MAX_SCHEDULES=500` (`main.py:102-104`).

   → **El diagnóstico va en el backend**, sobre `combinations_per_subject` completo y sin fusionar.

3. **La poda por créditos es rama muerta.** `creditLimit` es `final = 20`, no configurable (`schedule_provider.dart:45`), y `addSubject` rechaza antes de superarlo (`:173`). La suma siempre es ≤ 20 = `max_credits` ⟹ la poda de `schedule_generator.py:165` **nunca se dispara**. Los créditos no son causa posible.

4. **Las optimizaciones no filtran.** `optimizeGaps` / `optimizeFreeDays` solo ordenan (`:206-210`).

## 3. Decisión: bloquear agregar materias en estado roto

**Regla:** con ≥1 materia y 0 horarios, no se permite agregar más materias.

Hoy `addSubject` deja la materia puesta aunque falle (`schedule_provider.dart:180-186`), así que se pueden apilar materias sobre un estado ya roto. No tiene sentido para el usuario (si ya no hay horarios, agregar otra no los va a crear) y ensucia el diagnóstico: habría dos quiebres independientes y ya no existiría "una materia nueva culpable".

Con la regla se garantiza la **invariante I1**: *el estado anterior siempre tuvo ≥1 horario*. Como todo cambio se aplica al instante y regenera, el desbloqueo es automático.

> El diagnóstico se diseña **agnóstico a la acción**: no necesita saber si lo último fue agregar materia o tocar un filtro. I1 acota los casos, pero el algoritmo no depende de ella.

## 4. Marco formal: esto es un CSP y los filtros son unarios

El problema es un **CSP**:

- **Variables**: las materias.
- **Dominio** de una materia: sus `option_group`s (teórico + labs), después de aplicar filtros.
- **Restricción**: binaria, de no-solape de horas entre dos grupos elegidos.

**Todos los filtros son unarios** (`_meets_filters`):

| Filtro | Ámbito |
|--------|--------|
| `selected_nrcs` | por materia |
| `include_professors` / `exclude_professors` | por materia |
| `unavailable_slots` | por horario de la opción |

Ninguno es relacional: **los filtros solo encogen dominios**, nunca crean una restricción nueva entre materias. La única restricción relacional (el choque de horas) la fija la oferta.

**Consecuencia:** un CSP solo puede ser insatisfacible de **tres formas**. Esto es exhaustivo por construcción, no por enumeración a ojo:

| Forma | Definición |
|-------|-----------|
| **U1 — Dominio vacío** | Una materia se queda sin ninguna opción viable. |
| **U2 — Par sin soporte** | Dominios no vacíos, pero un par (A,B) no tiene **ninguna** combinación que conviva. |
| **U3 — Inconsistencia global (k≥3)** | Todos los pares tienen soporte, pero no existe asignación global. |

U3 absorbe 3, 4, …, n materias. **No hay una cuarta forma.**

## 5. Los dos ejes

Hay que separar **dónde vive** el conflicto de **quién tiene la culpa**. Son ejes independientes:

- **Forma** (U1/U2/U3) → determina **qué se puede nombrar** (una materia / un par / el conjunto).
- **Culpa** (datos / filtros / estructural) → determina **qué se sugiere**.

Como los filtros solo encogen dominios, la culpa se resuelve con **la misma pregunta repetida sin filtros**: si el problema persiste con `F = ∅`, es estructural; si desaparece, es del filtro.

### Matriz completa

| | **Datos** | **Filtros** | **Estructural** |
|---|---|---|---|
| **U1** dominio vacío | Materia sin oferta (§6.1) | Filtro mata la materia (§6.2) | **imposible** ✝ |
| **U2** par sin soporte | n/a | Filtro deja el par sin soporte (§6.4) | Cruce duro real (§6.3) |
| **U3** global k≥3 | n/a | Filtros llevan al palomar (§6.6) | Palomar real (§6.5) |

✝ **Demostrable:** una materia con ≥1 curso y sin filtros siempre tiene opción viable, porque `_has_conflict` **nunca compara un grupo consigo mismo** (`schedule_generator.py:220-222`): un grupo solo jamás entra en conflicto. Dominio nunca vacío ⟹ esa celda no existe.

> **Nota — "cuál filtro" no es una forma.** Preguntar si culpamos a un filtro o a la combinación de varios es una **sub-pregunta** de la columna *Filtros* (§7.2), no una cuarta forma de insatisfacibilidad. Mezclarla con U1/U2/U3 fue el error de la primera versión de esta RFC.

## 6. Los casos

### 6.1 U1 × Datos — Materia sin oferta

`get_combinations_for_subjects` devuelve menos materias de las pedidas → el endpoint retorna `[]` **sin generar** (`main.py:82-83`). Hoy es indistinguible de un cruce.

**Hoy es casi imposible:** el ETL crea `Materia` y `Curso` en la **misma iteración del mismo entry** (`parser.py:103-117`), y los `continue` que descartan entries malos (`:85`) ocurren **antes** de registrar la materia. Una `Materia` sin `Curso` no debería existir.

**Pero se vuelve real** el día que las materias se hagan persistentes (feature planeada): la lista de búsqueda sale de `get_all_subjects_summary()` → `SELECT ... FROM Materia` **sin join a `Curso`** (`repository.py:275`), así que aparecerían en el buscador materias sin oferta. Se implementa como **defensa**, no como bug actual.

### 6.2 U1 × Filtros — El filtro mata la materia sola

`SAT({X}, F) = false`: una materia sola, sin nadie con quien chocar, ya no tiene cursos viables. Trampas reales:

- Se excluyó a **todos** los profesores de la materia.
- El NRC seleccionado cae dentro de las **horas no disponibles**.
- **Se seleccionó solo el laboratorio** sin el teórico: el horario incluye el grupo completo (teórico + lab) y `_meets_filters` exige que los NRCs del horario sean **subconjunto** de los seleccionados (`:304`) → ningún horario pasa. `_expand_selected_nrcs` cubre el caso inverso (teórico → sus labs), no este.

Es el caso más claro y se chequea **primero**.

### 6.3 U2 × Estructural — Cruce duro real

`SAT({A,B}, ∅) = false`: **todo** curso de A choca con **todo** curso de B.

**Es una condición fuerte.** Solo se cumple cuando ambas materias tienen sus cursos apretados en la misma ventana. Con cursos repartidos **casi nunca aplica** — por eso este caso **no es el común**, aunque sea el más intuitivo.

Sí puede involucrar a **varias** materias a la vez (cursos de varios días — lo normal):

- **Programación**: curso único **lun, mar y mié** 8-10.
- **Cálculo** lun 8-10 · **Física** mar 8-10 · **Álgebra** mié 8-10 — las tres **coexisten** entre ellas.
- Programación choca con las tres, **una por una**. Hay que quitar **las tres** (o quitar Programación).

> **Corolario de I1:** si el estado anterior era satisfacible, las materias previas conviven en algún horario ⟹ ningún par entre ellas es duro. Los pares duros **siempre involucran a la materia nueva**. Aun así se chequean todos los pares: es barato y mantiene el diagnóstico agnóstico a la acción.

### 6.4 U2 × Filtros — El filtro deja el par sin soporte

`SAT({A,B}, ∅) = true` pero `SAT({A,B}, F) = false`. Sin filtros A y B caben; los filtros encogieron los dominios hasta que no quedó ninguna pareja compatible.

**Aquí no basta decir "es tu filtro":** hay usuarios que **no van a ceder el filtro** (filtraron a ese profesor o a esa franja por algo). Para ellos la pregunta útil es la otra: *"con mi filtro puesto, ¿qué materia estorba?"* → se reportan **las dos salidas**.

### 6.5 U3 × Estructural — Palomar real

Ningún par choca y aun así no cabe. **Este es el caso común**, no la excepción. Con varios cursos por materia:

| Materia | Cursos |
|---|---|
| Programación | lun 8-10 **o** mar 8-10 |
| Cálculo | lun 8-10 **o** mar 8-10 |
| Física | lun 8-10 **o** mar 8-10 |

Cada par cabe (una lunes, otra martes). **Las tres no**: tres materias, dos franjas.

**No hay culpable individual.** Decir "Programación choca con Cálculo" sería **falso**. Lo honesto y accionable es *qué quitar*: probar quitando una a la vez.

### 6.6 U3 × Filtros — Los filtros llevan al palomar

Igual que §6.5 pero el palomar aparece **solo por los filtros**: `SAT(S, ∅) = true`, todos los pares tienen soporte bajo `F`, y aun así `SAT(S, F) = false`. Filtraste Cálculo a 2 NRCs y Física a 2 NRCs y los dominios quedaron demasiado flacos.

Se reporta como palomar **y** se señala el filtro que desbloquea.

### 6.7 Nota — cursos sin horario ("fantasma")

`repository.py:159` (`if dia and hora_inicio and hora_final`): un `Curso` sin filas en `Clase` (el `LEFT JOIN` da NULL) genera una opción con **`schedules=[]`**. `_has_conflict` itera sobre `schedules` → cero iteraciones → **nunca choca con nada**.

Es alcanzable: `parser.py:121` descarta el `meetingTime` sin horas, pero `parser.py:117` inserta el curso igual.

**Consecuencia:** una materia con un curso fantasma es **siempre colocable** y nunca puede ser culpable. No es un bug del diagnóstico (ese curso de verdad no choca), pero explica un futuro *"¿por qué no me la señala?"*.

## 7. Algoritmo

### 7.1 Primitiva: oráculo de existencia

```
SAT(S, F) -> bool    # ¿existe AL MENOS UN horario con las materias S y los filtros F?
```

Es el backtracking actual con **salida temprana al primer horario válido**, sin enumerar, fusionar ni ordenar. Hoy `find_valid_schedules` explora **todo** el árbol siempre (por eso existe el cap de 500); para diagnosticar solo importa la existencia. Esa diferencia es la que hace viable todo lo demás.

Debe replicar **exactamente** la noción de validez del generador (mismas podas, mismo `_meets_filters`), o el diagnóstico podría contradecir al resultado.

### 7.2 Cascada

Los tres chequeos mapean 1:1 con las tres formas, de específico/barato a vago/caro. La primera que dispare manda: cualquiera de ellas ya explica el vacío.

```
Resultado vacío
│
├─ 0. ¿Faltan materias en `combinations`?   ──▶  U1×Datos (§6.1). FIN.
│
├─ 1. U1: ¿existe X con SAT({X}, F) = false?
│        sí ──▶ culpa = filtros (por ✝ nunca es estructural). FIN.
│
├─ 2. U2: pares (A,B) con SAT({A,B}, F) = false
│        sí ──▶ por cada par, SAT({A,B}, ∅):
│                 false ──▶ cruce duro real (§6.3)
│                 true  ──▶ el filtro dejó el par sin soporte (§6.4)
│               + leave-one-out para el menú de "qué quitar". FIN.
│
└─ 3. U3: SAT(S, ∅)
         false ──▶ palomar real (§6.5)
         true  ──▶ palomar por filtros (§6.6)
       + leave-one-out (qué quitar) + leave-one-filter-out (qué filtro desbloquea)
```

**Sub-pregunta de la columna Filtros — ¿cuál filtro?** Se prueba quitando **uno a la vez** (`SAT(S, F\{f})`). Los que desbloquean solos se reportan. Si ninguno solo lo logra, es la combinación. Granularidad: por `(tipo, materia)` para los filtros por materia, y por día para `unavailable_slots`.

> No se usa greedy: dependería del orden y culparía a filtros distintos según por dónde se empiece. El leave-one-out es independiente del orden.

## 8. Mensajes

| Caso | Mensaje |
|------|---------|
| §6.1 | *"**Cálculo** no tiene cursos en la oferta de este periodo. Quítala para continuar."* |
| §6.2 | *"Tu filtro de **Cálculo** no deja ningún curso disponible: relájalo o quita la materia."* |
| §6.3 (1 par) | *"**Física** se cruza con **Cálculo**: no hay forma de tomarlas juntas."* |
| §6.3 (varias) | *"**Programación** se cruza con **Cálculo**, **Física** y **Álgebra**. Tendrías que quitarlas todas —o quitar Programación."* |
| §6.4 | *"Con tus filtros, **Física** choca con **Cálculo**. Puedes quitar Cálculo, o relajar el filtro de profesor de Cálculo — con eso sí caben."* |
| §6.5 | *"**Programación** no cabe junto con las materias que ya tienes (con cada una por separado sí cabría). Si quitas **Cálculo** o **Física**, sí hay horarios."* |
| §6.6 | *"Tus filtros dejan sin opciones. Relajando **las horas del martes** sí hay horarios. Sin tocar filtros, si quitas **Cálculo** sí caben."* |
| Guarda §3 | *"Resuelve el cruce actual antes de agregar otra materia."* |

Reglas de redacción:

- En la columna **Estructural** **no se mencionan los filtros**: son irrelevantes y solo confunden.
- En la columna **Filtros** siempre se dan **las dos salidas**: relajar el filtro **o** quitar la materia (§6.4).
- Nunca se afirma un cruce que no existe sin filtros (por eso el orden de §7.2).

## 9. Contrato de API

El backend devuelve estructura; **el mensaje lo compone el frontend** (igual que hoy, `schedule_provider.dart:295-307`).

```jsonc
// GenerateScheduleResponse
{
  "schedules": [],
  "truncated": false,
  "diagnosis": {
    "shape": "sin_oferta" | "materia_sin_opciones" | "par_incompatible" | "conjunto_incompatible",
    "blame": "datos" | "filtros" | "estructural",
    "subjects": ["Cálculo"],                  // señaladas según shape
    "pairs": [["Física", "Cálculo"]],         // solo par_incompatible
    "removalOptions": ["Cálculo", "Física"],  // quitando esta sí hay horarios
    "blockingFilters": [                      // solo blame=filtros
      {"type": "unavailable_slots", "target": "martes"}
    ]
  }
}
```

`diagnosis` es `null` cuando hay horarios (no se calcula: costo cero en el camino feliz).

## 10. Costo

Con `n` materias (tope real ≈ 7: 20 créditos / ~3 por materia) y `|F|` filtros:

| Chequeo | Llamadas | Tamaño |
|---------|----------|--------|
| U1 | n | **1 materia** → trivial |
| U2 | n(n-1)/2 ≤ 21 | **2 materias** → microscópico |
| `SAT(S,∅)` | 1 | conjunto completo |
| Leave-one-out | ≤ n | n-1 materias |
| Leave-one-filter-out | ≤ \|F\| | conjunto completo |

**Peor caso, honestamente:** `SAT` es barato cuando responde `true` (corta al primer horario), **caro cuando responde `false`** (agota el árbol). Mitigantes:

1. El diagnóstico **solo corre con resultado ya vacío**: la exploración completa ya se pagó. **Costo cero en el camino feliz.**
2. U1 y U2 —los que resuelven casi todo— son sobre 1 y 2 materias.
3. La cascada corta apenas hay veredicto.

## 11. Fases

**Fase 1 (esta):** oráculo `SAT`, guarda de §3, y la cascada completa de §7.2 (U1, U2, U3 + atribución de culpa + leave-one-out + leave-one-filter-out). El mapa formal cierra sin huecos, así que no hay razón para partirlo.

**Fase 2 (si aparece la necesidad):** afinar el detalle del filtro (hoy *"el filtro de profesor de Cálculo"*; podría ser *"el profesor X"*).

## 12. Descartado (con razón)

| Idea | Por qué no |
|------|-----------|
| Guardar el historial de opciones descartadas | Innecesario: el diagnóstico se recalcula desde cero con `SAT`; el generador ya es stateless. |
| Diagnosticar en el frontend con la respuesta anterior | Los horarios vienen **fusionados** y **capados a 500**: ni limpios ni completos → respuestas falsas (§2.2). |
| Diagnosticar créditos | Rama muerta: el front bloquea antes (§2.3). |
| QuickXplain / MUS | Innecesario: U1+U2+U3 con leave-one-out cubren el mapa completo. Se reevalúa solo si aparece un caso que ninguno explique. |
| Greedy sobre filtros | Depende del orden → culparía a filtros distintos según por dónde se empiece (§7.2). |
| Chequeo pairwise como caso principal | Es U2, y U2 **casi nunca aplica** con cursos repartidos (§6.3). El caso común es U3 (§6.5). |
