from fastapi import APIRouter, HTTPException
from typing import Any

# Importa el modelo para usarlo como pista de tipo y respuesta
from ..models import Subject
# Importa el módulo repository desde la carpeta db
from ..db import repository

# Crea el APIRouter. Este se incluirá en el app principal de FastAPI.
router = APIRouter(
    prefix="/api",  # Prefijo para todas las rutas en este archivo
    tags=["subjects"], # Agrupa estas rutas en la documentación de Swagger/OpenAPI
)

@router.get('/subjects/{subject_code}', response_model=Subject, summary="Obtener detalles de una materia")
def get_subject_details(subject_code: str, name: str) -> Any:
    """
    Obtiene los detalles completos de una materia específica por su código Y nombre.
    El nombre se pasa como un parámetro de consulta (query parameter).
    Ejemplo: /api/subjects/ETI101?name=Ética%20y%20Cívica
    """
    # Llama a la función del repositorio con ambos argumentos.
    subject_data = repository.get_subject_by_code(subject_code, name)
    
    if not subject_data:
        raise HTTPException(status_code=404, detail="Materia no encontrada")
    
    return subject_data