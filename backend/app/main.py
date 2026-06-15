# main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import Response
from typing import List, Dict, Any 
import os

# Importa módulos y modelos. El '.' indica que son del mismo paquete 'app'
from .models import GenerateScheduleRequest, ClassOption
from .db import repository
from .services import schedule_generator
from .routes import subject_routes
from .routes import favorite_routes
from .auth.routes import router as auth_router

app = FastAPI(
    title="DH Schedule Generator API",
    description="API para generar horarios de la Universidad Tecnológica de Bolívar y consultar materias.",
    version="1.0.0"
)

# CORS. En producción la app es de mismo origen (Nginx sirve el build y proxya
# /api), por lo que no se necesita ningún origen cruzado y la lista queda vacía.
# En desarrollo, el dev-server de Flutter corre en otro puerto (p. ej.
# http://localhost:8080) y se habilita mediante la variable de entorno
# CORS_ALLOW_ORIGINS (orígenes separados por coma). Se evita "*" porque, junto a
# allow_credentials=True, obliga a reflejar cualquier origen (riesgo de
# seguridad) y el navegador bloquea las peticiones con cookies.
_cors_allow_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ALLOW_ORIGINS", "").split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Máximo de horarios devueltos por el generador. La explosión combinatoria puede
# producir decenas de miles de combinaciones; cargarlas todas en el cliente
# (sobre todo en móvil) agota la memoria y reinicia la pestaña. Como cualquier
# orden/filtro re-llama al generador, basta devolver los mejores N para el
# criterio actual. Configurable por env; 0 o negativo = sin límite.
_MAX_SCHEDULES = int(os.getenv("MAX_SCHEDULES", "500"))

# Ruta añadida para resolver problemática
app.include_router(subject_routes.router)

# Rutas de favoritos (horarios destacados)
app.include_router(favorite_routes.router)

# Rutas de autenticación OAuth
app.include_router(auth_router)


@app.get("/api/subjects", summary="Obtener lista de todas las materias")
def get_subjects_list():
    """
    Devuelve una lista ligera de todas las materias disponibles (código, nombre, créditos)
    para ser usada en el buscador del frontend.
    """
    # Llama a la función síncrona del repositorio.
    return repository.get_all_subjects_summary()

@app.post("/api/schedules/generate", response_model=List[List[ClassOption]], summary="Generar horarios válidos")
def generate_schedules_endpoint(request: GenerateScheduleRequest) -> List[List[ClassOption]]:
    """
    Recibe una lista de objetos de materia (código y nombre) y un diccionario de filtros.
    
    Ejecuta el algoritmo de backtracking y devuelve una lista de horarios válidos.
    Cada horario es una lista de las opciones de clase que lo componen.
    """
    if not request.subjects:
        raise HTTPException(status_code=400, detail="La lista de materias no puede estar vacía.")

    subjects_data = [s.model_dump() for s in request.subjects]
    combinations = repository.get_combinations_for_subjects(subjects_data)
    
    if not combinations or len(combinations) != len(request.subjects):
        empty_result: List[List[ClassOption]] = []
        return empty_result


    # Se define explícitamente el tipo del diccionario para Pylance.
    generation_params: Dict[str, Any] = {
        **request.filters,
        "credit_limit": request.credit_limit
    }

    # 2. Se pasan los dos argumentos que la función expecta.
    valid_schedules = schedule_generator.find_valid_schedules(
        combinations, generation_params
    )

    # Cap: devuelve solo los mejores N (ya vienen ordenados del generador).
    if 0 < _MAX_SCHEDULES < len(valid_schedules):
        valid_schedules = valid_schedules[:_MAX_SCHEDULES]

    # Devuelve los resultados.
    return valid_schedules

@app.get("/subjects")
def get_subject_data():
    BASE_DIR = os.path.join(os.path.dirname(__file__), "..")
    IMPORT_DIR = os.path.join(BASE_DIR, "scripts/shared_data")
    os.makedirs(IMPORT_DIR, exist_ok=True)
    filepath = os.path.join(IMPORT_DIR, "subject_data.json")
    if os.path.exists(filepath):
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
        return Response(content=content, media_type="application/json; charset=utf-8")
    return {"error": "subject_data.json no encontrado"}

