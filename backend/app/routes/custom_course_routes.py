# routes/custom_course_routes.py
"""
Endpoints CRUD para cursos personalizados del usuario.

Un curso personalizado es un curso que el usuario declara (uno que ya
decidió/matriculó, o una variación) para que el generador arme el horario a su
alrededor. Cuelga de una materia **existente** del catálogo — no se inventan
materias (la materia carga los créditos). Ver
docs/issues/17-07-2026-rfc-cursos-personalizados.md
"""
from typing import Optional, List
from fastapi import APIRouter, Cookie, HTTPException
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel

from ..auth.routes import get_authenticated_user
from ..db import repository

router = APIRouter(prefix="/api/custom-courses", tags=["custom-courses"])

# Tope defensivo por usuario (los favoritos tienen uno análogo).
MAX_CUSTOM_COURSES = 40


class Bloque(BaseModel):
    day: str
    time: str  # "HH:MM - HH:MM", igual que Schedule


class CreateCustomCourseRequest(BaseModel):
    code: str
    name: str
    bloques: List[Bloque]
    nrc: Optional[str] = None
    tipo: Optional[str] = None
    professor: Optional[str] = None
    campus: Optional[str] = None
    activo: bool = True


class UpdateCustomCourseRequest(BaseModel):
    bloques: Optional[List[Bloque]] = None
    nrc: Optional[str] = None
    tipo: Optional[str] = None
    professor: Optional[str] = None
    campus: Optional[str] = None
    activo: Optional[bool] = None


def _user_id(session_id: Optional[str]) -> int:
    user = get_authenticated_user(session_id)
    uid = user.get("db_user_id")
    if not uid:
        raise HTTPException(status_code=400, detail="Usuario no vinculado a la base de datos")
    return uid


@router.get("")
async def list_custom_courses(session_id: Optional[str] = Cookie(default=None)):
    """Lista todos los cursos personalizados del usuario (para el panel de gestión)."""
    uid = _user_id(session_id)
    cursos = await run_in_threadpool(repository.get_custom_courses, uid)
    return {"customCourses": cursos}


@router.post("")
async def create_custom_course(
    body: CreateCustomCourseRequest,
    session_id: Optional[str] = Cookie(default=None),
):
    """Crea un curso personalizado para una materia existente del catálogo."""
    uid = _user_id(session_id)

    if not body.bloques:
        raise HTTPException(status_code=400, detail="El curso debe tener al menos un bloque de horario.")

    # La materia debe existir: no se inventan materias (ver RFC §3).
    exists = await run_in_threadpool(repository.materia_exists, body.code, body.name)
    if not exists:
        raise HTTPException(status_code=404, detail="La materia no existe en el catálogo.")

    count = await run_in_threadpool(repository.count_custom_courses, uid)
    if count >= MAX_CUSTOM_COURSES:
        raise HTTPException(
            status_code=429,
            detail=f"Límite de {MAX_CUSTOM_COURSES} cursos personalizados alcanzado.",
        )

    bloques = [b.model_dump() for b in body.bloques]
    result = await run_in_threadpool(
        repository.create_custom_course,
        uid, body.code, body.name, bloques,
        body.nrc, body.tipo, body.professor, body.campus, body.activo,
    )
    return {"customCourse": result}


@router.patch("/{course_id}")
async def update_custom_course(
    course_id: int,
    body: UpdateCustomCourseRequest,
    session_id: Optional[str] = Cookie(default=None),
):
    """Actualiza campos de un curso personalizado (incluye el switch `activo`)."""
    uid = _user_id(session_id)
    bloques = [b.model_dump() for b in body.bloques] if body.bloques is not None else None
    result = await run_in_threadpool(
        repository.update_custom_course,
        course_id, uid, bloques, body.nrc, body.tipo,
        body.professor, body.campus, body.activo,
    )
    if result is None:
        raise HTTPException(status_code=404, detail="Curso personalizado no encontrado.")
    return {"customCourse": result}


@router.delete("/{course_id}")
async def delete_custom_course(
    course_id: int,
    session_id: Optional[str] = Cookie(default=None),
):
    """Elimina un curso personalizado. Valida ownership."""
    uid = _user_id(session_id)
    deleted = await run_in_threadpool(repository.delete_custom_course, course_id, uid)
    if not deleted:
        raise HTTPException(status_code=404, detail="Curso personalizado no encontrado.")
    return {"message": "Curso personalizado eliminado"}
