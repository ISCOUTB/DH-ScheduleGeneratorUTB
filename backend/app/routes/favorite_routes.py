# routes/favorite_routes.py
"""
Endpoints para gestionar horarios destacados (favoritos) del usuario.
"""
import json
from typing import Optional
from fastapi import APIRouter, Cookie, HTTPException
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel
from ..auth.routes import get_authenticated_user, CURRENT_TERM
from ..db import repository

router = APIRouter(prefix="/api/favorites", tags=["favorites"])

# Límite de favoritos por usuario por término
MAX_FAVORITES_PER_TERM = 20


@router.get("/terms")
async def get_favorite_terms(
    session_id: Optional[str] = Cookie(default=None),
):
    """
    Retorna los términos que tienen favoritos para el usuario + el término actual.
    """
    user = get_authenticated_user(session_id)
    user_id = user.get("db_user_id")
    if not user_id:
        raise HTTPException(status_code=400, detail="Usuario no vinculado a la base de datos")

    terms = await run_in_threadpool(
        repository.get_favorite_terms, user_id
    )

    # Asegurar que el término actual siempre aparezca
    if CURRENT_TERM not in terms:
        terms.insert(0, CURRENT_TERM)

    return {
        "currentTerm": CURRENT_TERM,
        "availableTerms": terms,
    }


@router.get("/status")
async def get_favorites_status(
    nrcs: str = "",
    session_id: Optional[str] = Cookie(default=None),
):
    """
    Estado actual de cupos de una lista de NRCs (Fase 2: estado visual).

    Query param `nrcs`: lista separada por comas (ej. "12345,67890").
    Retorna un mapa { nrc: { available, total } }. Los NRC inexistentes en la
    tabla Curso se omiten (el frontend los trata como 'eliminado').

    Solo refleja el término actual; el frontend no lo invoca para periodos
    pasados (ver RFC Fase 2, sección 2.6). Requiere sesión activa.
    """
    # Valida la sesión (lanza 401 si no hay). No se necesita el user_id: el
    # estado de cupos no depende del usuario, pero el endpoint es privado.
    get_authenticated_user(session_id)

    nrc_list = [n.strip() for n in nrcs.split(",") if n.strip()]
    if not nrc_list:
        return {}

    return await run_in_threadpool(repository.get_nrc_seats, nrc_list)


class CreateFavoriteRequest(BaseModel):
    """Body para crear un favorito."""
    signature: str
    schedule: list  # Lista de ClassOption serializada


@router.get("")
async def get_favorites(
    term: Optional[str] = None,
    session_id: Optional[str] = Cookie(default=None),
):
    """
    Lista los horarios destacados del usuario autenticado para un término.
    Si no se especifica term, usa el término actual.
    """
    user = get_authenticated_user(session_id)
    user_id = user.get("db_user_id")
    if not user_id:
        raise HTTPException(status_code=400, detail="Usuario no vinculado a la base de datos")

    effective_term = term or CURRENT_TERM

    favorites = await run_in_threadpool(
        repository.get_favorites, user_id, effective_term
    )

    # Serializar created_at a string para JSON
    for fav in favorites:
        if fav.get("created_at"):
            fav["created_at"] = str(fav["created_at"])

    return {
        "term": effective_term,
        "count": len(favorites),
        "maxAllowed": MAX_FAVORITES_PER_TERM,
        "favorites": favorites,
    }


@router.post("")
async def create_favorite(
    body: CreateFavoriteRequest,
    session_id: Optional[str] = Cookie(default=None),
):
    """
    Crea un horario destacado para el usuario autenticado.
    Usa el término actual del servidor.
    Si ya existe (misma signature), retorna 409.
    """
    user = get_authenticated_user(session_id)
    user_id = user.get("db_user_id")
    if not user_id:
        raise HTTPException(status_code=400, detail="Usuario no vinculado a la base de datos")

    # Verificar límite
    current_count = await run_in_threadpool(
        repository.count_favorites, user_id, CURRENT_TERM
    )
    if current_count >= MAX_FAVORITES_PER_TERM:
        raise HTTPException(
            status_code=429,
            detail=f"Límite de {MAX_FAVORITES_PER_TERM} horarios destacados alcanzado para este período"
        )

    result = await run_in_threadpool(
        repository.create_favorite,
        user_id,
        CURRENT_TERM,
        body.signature,
        body.schedule,
    )

    if result is None:
        raise HTTPException(status_code=409, detail="Este horario ya está en tus destacados")

    if result.get("created_at"):
        result["created_at"] = str(result["created_at"])

    return {"message": "Horario destacado guardado", "favorite": result}


@router.delete("/{favorite_id}")
async def delete_favorite(
    favorite_id: int,
    session_id: Optional[str] = Cookie(default=None),
):
    """
    Elimina un horario destacado del usuario autenticado.
    Valida ownership: solo puede eliminar sus propios favoritos.
    """
    user = get_authenticated_user(session_id)
    user_id = user.get("db_user_id")
    if not user_id:
        raise HTTPException(status_code=400, detail="Usuario no vinculado a la base de datos")

    deleted = await run_in_threadpool(
        repository.delete_favorite, favorite_id, user_id
    )

    if not deleted:
        raise HTTPException(status_code=404, detail="Favorito no encontrado")

    return {"message": "Horario destacado eliminado"}
