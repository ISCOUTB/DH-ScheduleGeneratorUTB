# main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import Response
from typing import List, Dict, Any 
import os

# Importa módulos y modelos. El '.' indica que son del mismo paquete 'app'
from .models import (
    GenerateScheduleRequest,
    GenerateScheduleResponse,
    ScheduleDiagnosis,
    ClassOption,
    CustomCourseInput,
)
from .db import repository
from .services import schedule_generator
from .services import schedule_diagnostics
from .routes import subject_routes
from .routes import favorite_routes
from .routes import custom_course_routes
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

# Máximo de horarios devueltos a clientes MÓVILES. La explosión combinatoria
# puede producir decenas de miles de combinaciones; cargarlas todas agota la
# memoria del navegador móvil y reinicia la pestaña. Escritorio no se limita.
# Como cualquier orden/filtro re-llama al generador, basta devolver los mejores
# N para el criterio actual. Configurable por env; 0 o negativo = sin límite.
_MAX_SCHEDULES = int(os.getenv("MAX_SCHEDULES", "500"))

# Ruta añadida para resolver problemática
app.include_router(subject_routes.router)

# Rutas de favoritos (horarios destacados)
app.include_router(favorite_routes.router)

# Rutas de cursos personalizados
app.include_router(custom_course_routes.router)

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


@app.get("/api/subjects-catalog", summary="Catálogo completo de materias (con y sin oferta)")
def get_subjects_catalog():
    """
    Devuelve TODAS las materias del catálogo, tengan oferta o no, para el selector
    de materia de un curso personalizado (ahí sí se permite elegir una materia sin
    cursos vigentes). El buscador normal usa `/api/subjects`.
    """
    return repository.get_all_subjects_catalog()

def _custom_option_group(cc: CustomCourseInput) -> List[ClassOption]:
    """Convierte un curso personalizado en un `option_group` (una sola opción).

    Es una materia con dominio de 1: el backtracking la trata igual que a
    cualquier otra. El NRC ya viene resuelto del backend (real o sintético
    ``CP{id}``). Cupos ficticios (1/1): es un curso que el usuario ya tiene.
    """
    return [
        ClassOption(
            subjectName=cc.name,
            subjectCode=cc.code,
            type=cc.etiqueta or cc.type or "Personalizado",
            schedules=cc.bloques,
            # Vacío si el usuario no puso profesor: la UI/descargas muestran el
            # profesor solo cuando existe (para un curso personalizado no hay uno
            # "oficial"). Ver detalle en schedule_overview / schedule_export.
            professor=cc.professor or "",
            nrc=cc.nrc,
            groupId=0,
            credits=cc.credits,
            campus=cc.campus or "",
            seatsAvailable=1,
            seatsMaximum=1,
            isCustom=True,
        )
    ]


@app.post("/api/schedules/generate", response_model=GenerateScheduleResponse, summary="Generar horarios válidos")
def generate_schedules_endpoint(request: GenerateScheduleRequest) -> GenerateScheduleResponse:
    """
    Recibe una lista de objetos de materia (código y nombre) y un diccionario de filtros.

    Ejecuta el algoritmo de backtracking y devuelve los horarios válidos junto con
    `truncated`, que indica si se aplicó el cap móvil y había más resultados.
    """
    if not request.subjects:
        raise HTTPException(status_code=400, detail="La lista de materias no puede estar vacía.")

    subjects_data = [s.model_dump() for s in request.subjects]
    real_combos = repository.get_combinations_for_subjects(subjects_data)

    # Índice de la oferta real por (código, nombre).
    real_by_key: Dict[Any, Any] = {}
    for subject_combos in real_combos:
        if subject_combos and subject_combos[0]:
            opt = subject_combos[0][0]
            real_by_key[(opt.subject_code, opt.subject_name)] = subject_combos

    # Cursos personalizados activos por materia. Cuando una materia trae al menos
    # uno, su dominio son ESOS (reemplaza la oferta real, no se suma) — ver RFC §5.
    custom_by_key: Dict[Any, list] = {}
    for cc in request.custom_courses:
        custom_by_key.setdefault((cc.code, cc.name), []).append(cc)

    # Se arma `combinations` en el orden de request.subjects. Una materia con
    # cursos personalizados usa esos; si no, la oferta real; si no tiene ninguno,
    # falta (sin oferta y sin curso personalizado).
    combinations: List[Any] = []
    missing: List[str] = []
    for s in request.subjects:
        key = (s.code, s.name)
        if key in custom_by_key:
            combinations.append([_custom_option_group(cc) for cc in custom_by_key[key]])
        elif key in real_by_key:
            combinations.append(real_by_key[key])
        else:
            missing.append(s.name)

    # Materia sin oferta y sin curso personalizado: el generador no puede correr.
    # No es un cruce (ver RFC diagnóstico §6.1).
    if missing:
        return GenerateScheduleResponse(
            schedules=[],
            truncated=False,
            diagnosis=ScheduleDiagnosis(
                shape="sin_oferta",
                blame="datos",
                subjects=missing,
                removalOptions=missing,
            ),
        )


    # Se define explícitamente el tipo del diccionario para Pylance.
    # El generador lee el tope bajo la clave 'max_credits'.
    generation_params: Dict[str, Any] = {
        **request.filters,
        "max_credits": request.credit_limit
    }

    # 2. Se pasan los dos argumentos que la función expecta.
    valid_schedules = schedule_generator.find_valid_schedules(
        combinations, generation_params
    )

    # Sin horarios: se explica por qué (materia sin opciones, par incompatible o
    # el conjunto). Solo se calcula en este camino, así que no cuesta nada cuando
    # sí hay resultados. Ver docs/issues/17-07-2026-rfc-diagnostico-sin-horarios.md
    if not valid_schedules:
        return GenerateScheduleResponse(
            schedules=[],
            truncated=False,
            diagnosis=schedule_diagnostics.diagnose(combinations, generation_params),
        )

    # Cap solo para clientes móviles: devuelve los mejores N (ya vienen
    # ordenados del generador). Escritorio recibe todos. `truncated` avisa al
    # frontend que había más (para mostrar "N+").
    truncated = False
    if request.is_mobile and 0 < _MAX_SCHEDULES < len(valid_schedules):
        truncated = True
        valid_schedules = valid_schedules[:_MAX_SCHEDULES]

    return GenerateScheduleResponse(schedules=valid_schedules, truncated=truncated)

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

