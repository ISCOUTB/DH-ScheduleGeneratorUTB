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

app = FastAPI(
    title="DH Schedule Generator API",
    description="API para generar horarios de la Universidad Tecnológica de Bolívar y consultar materias.",
    version="1.0.0"
)

# Middleware para permitir que el frontend (que corre en otro dominio/puerto) se comunique con esta API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ruta añadida para resolver problemática
app.include_router(subject_routes.router)


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
