# routes/planning_routes.py
"""
Planificación del período siguiente (HU #380 de la app móvil).

El estudiante arma la lista de materias que piensa ver el próximo período, así
se sabe de antemano qué materias se quieren ver (la vista `demanda_planificacion`
da los conteos, solo de 10 estudiantes o más). No hay sugerencias: las agrega a
mano desde la lista del período (`materia_planificable`, que se carga con
scripts/cargar_lista_planificacion.py), que trae también las materias que no se
dictan este período.

El período y la lista son públicos (salen de la oferta y de las mallas). El plan
y las preferencias de horario son de quien tiene la sesión (cookie de la web o
Bearer de la app), nunca de un id que venga en el cuerpo.
"""
from datetime import datetime
from decimal import Decimal
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel

from ..auth.routes import require_user
from ..db import repository

router = APIRouter(prefix="/api/planning", tags=["planning"])

# El mismo tope de créditos del generador (`max_credits` por defecto) y de la app.
MAX_PLAN_CREDITS = 20
# Tope defensivo de materias por plan.
MAX_PLAN_SUBJECTS = 30

# Preferencias de horario: las opciones de cada pregunta, en su orden canónico
# (los mismos valores de la app). La opción exclusiva va sola en su pregunta.
JORNADAS = ("morning", "afternoon", "night", "noPreference")
DIAS_LIBRES = ("Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado")
MOTIVOS = ("work", "internship", "other", "preferNotToSay")
# (campo del JSON, columna de plan_estudiante, opciones, opción exclusiva)
_PREGUNTAS = (
    ("dayParts", "jornadas", JORNADAS, "noPreference"),
    ("preferredFreeDays", "dias_libres", DIAS_LIBRES, None),
    ("reasons", "motivos", MOTIVOS, "preferNotToSay"),
)


class PlanRequest(BaseModel):
    codes: List[str]


class PreferencesRequest(BaseModel):
    """Las tres respuestas; una que no viene (o viene null) queda vacía."""

    dayParts: Optional[List[str]] = None
    preferredFreeDays: Optional[List[str]] = None
    reasons: Optional[List[str]] = None


def _iso(fecha: datetime | None) -> str | None:
    return fecha.isoformat() if fecha else None


def _creditos(valor: Decimal | None) -> float | None:
    return float(valor) if valor is not None else None


def _numero(valor: Decimal) -> str:
    return str(int(valor)) if valor == int(valor) else str(valor.normalize())


def _user_id(user: dict) -> int:
    uid = user.get("db_user_id")
    if not uid:
        raise HTTPException(status_code=400, detail="Usuario no vinculado a la base de datos")
    return uid


async def _periodo(term: str) -> Dict[str, Any]:
    """El período `term`; 404 si no existe o es un borrador."""
    periodo = await run_in_threadpool(repository.get_planning_term, term)
    if not periodo or periodo["estado"] == "borrador":
        raise HTTPException(status_code=404, detail="Período de planificación no encontrado.")
    return periodo


def _no_editable(periodo: Dict[str, Any]) -> HTTPException:
    return HTTPException(
        status_code=409,
        detail=f"La planificación de {periodo['etiqueta']} no está abierta.",
    )


def _plan(periodo: Dict[str, Any], plan: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "term": periodo["periodo"],
        "editable": bool(periodo["editable"]),
        "updatedAt": _iso(plan["updated_at"]),
        "subjects": [
            {
                "code": m["codigo"],
                "name": m["nombre"],
                "credits": _creditos(m["creditos"]),
                "active": m["activa"],
            }
            for m in plan["subjects"]
        ],
    }


def _preferencias(periodo: Dict[str, Any], guardadas: Dict[str, Any]) -> Dict[str, Any]:
    respuesta: Dict[str, Any] = {
        "term": periodo["periodo"],
        "editable": bool(periodo["editable"]),
        "updatedAt": _iso(guardadas["preferencias_actualizadas"]),
    }
    for campo, columna, opciones, _ in _PREGUNTAS:
        elegidas = guardadas[columna] or []
        respuesta[campo] = [o for o in opciones if o in elegidas]
    return respuesta


def _respuestas(body: PreferencesRequest) -> Dict[str, List[str]]:
    """Las tres respuestas de `body` por columna, en el orden canónico.

    400 con una opción repetida; 422 con una opción que no existe (la nombra) o
    con la opción exclusiva junto a otra de su pregunta."""
    dadas = {campo: getattr(body, campo) or [] for campo, _, _, _ in _PREGUNTAS}
    for campo, valores in dadas.items():
        vistos: set[str] = set()
        for valor in valores:
            if valor in vistos:
                raise HTTPException(status_code=400, detail=f"La opción {valor} está repetida en {campo}.")
            vistos.add(valor)
    for campo, _, opciones, _ in _PREGUNTAS:
        desconocidas = [v for v in dadas[campo] if v not in opciones]
        if desconocidas:
            raise HTTPException(
                status_code=422,
                detail=f"Estas opciones no existen en {campo}: {', '.join(desconocidas)}.",
            )
    for campo, _, _, exclusiva in _PREGUNTAS:
        if exclusiva in dadas[campo] and len(dadas[campo]) > 1:
            raise HTTPException(
                status_code=422,
                detail=f"{exclusiva} va sola: no se puede elegir junto a otras opciones en {campo}.",
            )
    return {columna: [o for o in opciones if o in dadas[campo]] for campo, columna, opciones, _ in _PREGUNTAS}


@router.get("/current")
async def current_term():
    """El período que se está planificando: abierto y dentro de su ventana."""
    periodo = await run_in_threadpool(repository.get_planning_term_current)
    if not periodo:
        raise HTTPException(status_code=404, detail="No hay un período en planificación.")
    return {
        "term": periodo["periodo"],
        "label": periodo["etiqueta"],
        "listVersion": periodo["version_lista"],
        "opensAt": _iso(periodo["abre"]),
        "closesAt": _iso(periodo["cierra"]),
    }


@router.get("/{term}/subjects")
async def term_subjects(term: str):
    """La lista de materias del período (las activas), por nombre."""
    periodo = await _periodo(term)
    materias = await run_in_threadpool(repository.get_planning_subjects, periodo["id"])
    return {
        "term": periodo["periodo"],
        "listVersion": periodo["version_lista"],
        "subjects": [
            {
                "code": m["codigo"],
                "name": m["nombre"],
                "credits": _creditos(m["creditos"]),
                "area": m["area"],
                "levels": m["niveles"],
                "programs": m["programas"],
                "nameTruncated": m["nombre_cortado"],
                "equivalentCodes": list(m["equivalentes"]),
            }
            for m in materias
        ],
    }


@router.get("/{term}/plan")
async def get_plan(term: str, user: dict = Depends(require_user)):
    """El plan de quien tiene la sesión (vacío si no tiene)."""
    uid = _user_id(user)
    periodo = await _periodo(term)
    plan = await run_in_threadpool(repository.get_student_plan, uid, periodo["id"])
    return _plan(periodo, plan)


@router.put("/{term}/plan")
async def put_plan(term: str, body: PlanRequest, user: dict = Depends(require_user)):
    """Reemplaza el plan de quien tiene la sesión por `codes`, en ese orden.

    Revisa lo mismo que la app: el período abierto, sin materias repetidas,
    solo materias de la lista y hasta 20 créditos. Una materia que salió de la
    lista se conserva si ya estaba en el plan. Repetirlo no cambia el resultado.
    """
    uid = _user_id(user)
    periodo = await _periodo(term)
    if not periodo["editable"]:
        raise _no_editable(periodo)

    codigos = [c.strip() for c in body.codes]
    if any(not c for c in codigos):
        raise HTTPException(status_code=400, detail="Hay un código de materia vacío.")
    if len(codigos) > MAX_PLAN_SUBJECTS:
        raise HTTPException(
            status_code=400,
            detail=f"Un plan tiene como máximo {MAX_PLAN_SUBJECTS} materias.",
        )
    vistos: set[str] = set()
    for codigo in codigos:
        if codigo in vistos:
            raise HTTPException(status_code=400, detail=f"La materia {codigo} está repetida.")
        vistos.add(codigo)

    # El período, las materias de la lista y los créditos se revisan dentro de
    # la transacción del guardado, con la fila del plan bloqueada.
    try:
        await run_in_threadpool(
            repository.replace_student_plan, uid, periodo["id"], codigos, MAX_PLAN_CREDITS
        )
    except repository.PlanningTermNotEditable:
        raise _no_editable(periodo)
    except repository.PlanSubjectsNotInList as e:
        raise HTTPException(
            status_code=422,
            detail=f"Estas materias no están en la lista de {periodo['etiqueta']}: {', '.join(e.codigos)}.",
        )
    except repository.PlanOverCreditLimit as e:
        raise HTTPException(
            status_code=422,
            detail=f"El plan pasa del tope de {MAX_PLAN_CREDITS} créditos ({_numero(e.total)}).",
        )
    plan = await run_in_threadpool(repository.get_student_plan, uid, periodo["id"])
    return _plan(periodo, plan)


@router.get("/{term}/preferences")
async def get_preferences(term: str, user: dict = Depends(require_user)):
    """Las preferencias de horario de quien tiene la sesión (vacías si no respondió)."""
    uid = _user_id(user)
    periodo = await _periodo(term)
    guardadas = await run_in_threadpool(repository.get_plan_preferences, uid, periodo["id"])
    return _preferencias(periodo, guardadas)


@router.put("/{term}/preferences")
async def put_preferences(term: str, body: PreferencesRequest, user: dict = Depends(require_user)):
    """Reemplaza las tres respuestas de quien tiene la sesión (jornadas, días
    libres y motivos) y las devuelve como el GET. Sin plan, lo crea vacío.

    El período se revisa otra vez dentro de la transacción del guardado: si se
    cerró en el medio, 409 y no se guarda nada."""
    uid = _user_id(user)
    periodo = await _periodo(term)
    if not periodo["editable"]:
        raise _no_editable(periodo)
    respuestas = _respuestas(body)
    try:
        guardadas = await run_in_threadpool(
            repository.save_plan_preferences,
            uid,
            periodo["id"],
            respuestas["jornadas"],
            respuestas["dias_libres"],
            respuestas["motivos"],
        )
    except repository.PlanningTermNotEditable:
        raise _no_editable(periodo)
    return _preferencias(periodo, guardadas)
