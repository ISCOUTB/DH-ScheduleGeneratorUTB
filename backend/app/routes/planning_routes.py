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
es de quien tiene la sesión (cookie de la web o Bearer de la app), nunca de un
id que venga en el cuerpo.
"""
from datetime import datetime
from decimal import Decimal
from typing import Any, Dict, List

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


class PlanRequest(BaseModel):
    codes: List[str]


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
        raise HTTPException(
            status_code=409,
            detail=f"La planificación de {periodo['etiqueta']} no está abierta.",
        )

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

    materias = await run_in_threadpool(repository.get_planning_subjects_by_code, periodo["id"], codigos)
    actual = await run_in_threadpool(repository.get_student_plan, uid, periodo["id"])
    ya_estaban = {m["codigo"] for m in actual["subjects"]}
    fuera = [
        c for c in codigos
        if c not in materias or (not materias[c]["activa"] and c not in ya_estaban)
    ]
    if fuera:
        raise HTTPException(
            status_code=422,
            detail=f"Estas materias no están en la lista de {periodo['etiqueta']}: {', '.join(fuera)}.",
        )
    total = sum((materias[c]["creditos"] or Decimal(0) for c in codigos), Decimal(0))
    if total > MAX_PLAN_CREDITS:
        raise HTTPException(
            status_code=422,
            detail=f"El plan pasa del tope de {MAX_PLAN_CREDITS} créditos ({_numero(total)}).",
        )

    await run_in_threadpool(
        repository.save_student_plan, uid, periodo["id"], [materias[c]["id"] for c in codigos]
    )
    plan = await run_in_threadpool(repository.get_student_plan, uid, periodo["id"])
    return _plan(periodo, plan)
