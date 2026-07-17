"""
Diagnóstico de por qué no se generó ningún horario.

Ver `docs/issues/17-07-2026-rfc-diagnostico-sin-horarios.md`.

Resumen del marco: el problema es un CSP (variables = materias, dominio = sus
`option_group`s, restricción binaria = no-solape). Todos los filtros de
`_meets_filters` son **unarios**: solo encogen dominios, nunca crean una
restricción nueva entre materias. Por eso un resultado vacío solo puede tener
tres formas, y son exhaustivas:

  U1  dominio vacío        → una materia sola ya no tiene opción viable
  U2  par sin soporte      → un par (A,B) no tiene ninguna combinación que conviva
  U3  inconsistencia global → todos los pares tienen soporte, pero el conjunto no cabe

Eje aparte (independiente de la forma): **la culpa**. Como los filtros solo
encogen dominios, se resuelve repitiendo la misma pregunta sin filtros: si el
problema persiste con F=∅ es estructural; si desaparece, es del filtro.

Solo se ejecuta cuando el generador ya devolvió vacío, así que no cuesta nada en
el camino feliz.
"""
from typing import Any, Dict, List, Optional, Tuple

from ..models import ClassOption
from .schedule_generator import has_any_schedule, subject_key

# Claves de `filters` que NO son filtros del usuario: son parámetros de
# generación y deben conservarse al preguntar "¿y sin filtros?".
_NON_FILTER_KEYS = ("max_credits", "optimizeGaps", "optimizeFreeDays")

# Filtros unarios por materia: {codigo_materia: [...]}.
_PER_SUBJECT_FILTERS = ("selected_nrcs", "include_professors", "exclude_professors")

# Filtro unario por día: {dia: [horas]}.
_PER_DAY_FILTERS = ("unavailable_slots",)

Combos = List[List[List[ClassOption]]]


def _subject_name(subject_combos: List[List[ClassOption]]) -> str:
    """Nombre visible de la materia a partir de sus combinaciones."""
    return subject_combos[0][0].subject_name


def _subject_key(subject_combos: List[List[ClassOption]]) -> str:
    """Llave (código, nombre) de la materia: la misma con la que llegan los filtros."""
    return subject_key(subject_combos[0][0])


def _strip_filters(filters: Dict[str, Any]) -> Dict[str, Any]:
    """Los mismos parámetros de generación pero sin ningún filtro del usuario."""
    return {k: v for k, v in filters.items() if k in _NON_FILTER_KEYS}


def _user_filter_keys(filters: Dict[str, Any]) -> List[Tuple[str, str]]:
    """
    Lista de filtros individuales activos como (tipo, clave).

    La granularidad es por materia para los filtros por materia, y por día para
    las horas no disponibles: es la unidad que el usuario reconoce y puede
    relajar por separado.
    """
    keys: List[Tuple[str, str]] = []
    for ftype in _PER_SUBJECT_FILTERS + _PER_DAY_FILTERS:
        section = filters.get(ftype) or {}
        if isinstance(section, dict):
            for target, value in section.items():
                if value:  # una lista vacía no restringe nada
                    keys.append((ftype, target))
    return keys


def _without_filter(filters: Dict[str, Any], ftype: str, target: str) -> Dict[str, Any]:
    """Copia de `filters` sin ese filtro puntual."""
    reduced = dict(filters)
    section = dict(reduced.get(ftype) or {})
    section.pop(target, None)
    if section:
        reduced[ftype] = section
    else:
        reduced.pop(ftype, None)
    return reduced


def _filter_label(ftype: str, target: str, key_to_name: Dict[str, str]) -> Dict[str, str]:
    """Etiqueta estructurada del filtro; el texto lo compone el frontend."""
    return {
        "type": ftype,
        # Para filtros por materia el target es la llave "código|nombre": se
        # traduce al nombre visible. Para `unavailable_slots` el target ya es el
        # día y no está en el mapa, así que pasa tal cual.
        "target": key_to_name.get(target, target),
    }


def _removal_options(combos: Combos, filters: Dict[str, Any]) -> List[str]:
    """
    Menú de "qué quitar": materias tales que, quitándolas, sí hay horarios.

    Independiente del orden (a diferencia de un greedy): se prueba cada una
    contra el mismo estado. Puede salir vacío, y eso también informa — significa
    que quitar una sola no alcanza.
    """
    options: List[str] = []
    for i in range(len(combos)):
        rest = combos[:i] + combos[i + 1:]
        if rest and has_any_schedule(rest, filters):
            options.append(_subject_name(combos[i]))
    return options


def _blocking_filters(
    combos: Combos,
    filters: Dict[str, Any],
    key_to_name: Dict[str, str],
) -> List[Dict[str, str]]:
    """Filtros que, quitados por sí solos, desbloquean la generación."""
    blocking: List[Dict[str, str]] = []
    for ftype, target in _user_filter_keys(filters):
        if has_any_schedule(combos, _without_filter(filters, ftype, target)):
            blocking.append(_filter_label(ftype, target, key_to_name))
    return blocking


def diagnose(combos: Combos, filters: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Explica un resultado vacío.

    **Precondición:** el generador ya devolvió vacío para estas materias y
    filtros; el llamador debe garantizarlo. No se revalida (sería pagar otra
    exploración completa del árbol para confirmar algo que ya se sabe), así que
    llamarla sobre un conjunto satisfacible devuelve un veredicto sin sentido.

    La cascada va de específico/barato a vago/caro (U1 → U2 → U3); la primera
    forma que dispare manda, porque cualquiera de ellas ya explica el vacío.
    """
    if not combos:
        return None

    bare = _strip_filters(filters)
    has_user_filters = bool(_user_filter_keys(filters))
    names = [_subject_name(c) for c in combos]
    key_to_name = {_subject_key(c): _subject_name(c) for c in combos}

    # ── U1: ¿alguna materia se quedó sin opciones ella sola? ────────────────
    # Barato (1 materia por llamada) y es lo más específico que se puede decir.
    dead = [
        names[i] for i in range(len(combos))
        if not has_any_schedule([combos[i]], filters)
    ]
    if dead:
        # Sin filtros esto es imposible: un grupo solo nunca choca consigo mismo
        # (`_has_conflict` salta misma materia+grupo), así que el dominio no
        # puede quedar vacío. Si igual pasara, es un problema de datos.
        blame = "filtros" if has_user_filters else "datos"
        return {
            "shape": "materia_sin_opciones",
            "blame": blame,
            "subjects": dead,
            "pairs": [],
            "removalOptions": dead,
            "blockingFilters": (
                _blocking_filters(combos, filters, key_to_name)
                if blame == "filtros" else []
            ),
        }

    # ── U2: ¿algún par no tiene ninguna combinación compatible? ─────────────
    # n(n-1)/2 llamadas de 2 materias: microscópicas.
    pairs: List[List[str]] = []
    structural_pair = False
    for i in range(len(combos)):
        for j in range(i + 1, len(combos)):
            if has_any_schedule([combos[i], combos[j]], filters):
                continue
            pairs.append([names[i], names[j]])
            # La culpa, par por par: ¿chocan también sin filtros?
            if not has_any_schedule([combos[i], combos[j]], bare):
                structural_pair = True

    if pairs:
        return {
            "shape": "par_incompatible",
            # Si algún par choca hasta sin filtros, el problema es estructural
            # aunque haya filtros puestos: relajarlos no salvaría ese par.
            "blame": "estructural" if structural_pair else "filtros",
            "subjects": [],
            "pairs": pairs,
            "removalOptions": _removal_options(combos, filters),
            "blockingFilters": (
                _blocking_filters(combos, filters, key_to_name)
                if not structural_pair else []
            ),
        }

    # ── U3: todos los pares tienen soporte y aun así no cabe (palomar) ──────
    # Es el caso común con varios cursos por materia. No hay culpable individual:
    # lo único honesto es el menú de qué quitar.
    blame = "estructural" if not has_any_schedule(combos, bare) else "filtros"
    return {
        "shape": "conjunto_incompatible",
        "blame": blame,
        "subjects": names,
        "pairs": [],
        "removalOptions": _removal_options(combos, filters),
        "blockingFilters": (
            _blocking_filters(combos, filters, key_to_name)
            if blame == "filtros" else []
        ),
    }
