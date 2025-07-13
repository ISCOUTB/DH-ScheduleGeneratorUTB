# main.py
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse
from starlette.responses import Response
from typing import List
import os
import re

# Importamos nuestros módulos y modelos. El '.' indica que son del mismo paquete 'app'
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

# Función para detectar dispositivos móviles
def is_mobile_device(user_agent: str) -> bool:
    """
    Detecta si el dispositivo es móvil basado en el User-Agent
    """
    mobile_patterns = [
        r'Mobile', r'Android', r'iPhone', r'iPad', r'iPod',
        r'BlackBerry', r'Windows Phone', r'Opera Mini'
    ]
    pattern = '|'.join(mobile_patterns)
    return bool(re.search(pattern, user_agent, re.IGNORECASE))

# Configurar archivos estáticos para la versión web móvil
FRONTEND_WEB_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "frontend-web")
if os.path.exists(FRONTEND_WEB_DIR):
    app.mount("/static", StaticFiles(directory=FRONTEND_WEB_DIR), name="static")

@app.get("/", response_class=HTMLResponse)
async def serve_frontend(request: Request):
    """
    Endpoint principal que detecta el dispositivo y sirve el contenido apropiado
    """
    user_agent = request.headers.get("user-agent", "")
    
    if is_mobile_device(user_agent):
        # Servir el HTML de frontend-web para dispositivos móviles
        html_path = os.path.join(FRONTEND_WEB_DIR, "index.html")
        if os.path.exists(html_path):
            with open(html_path, "r", encoding="utf-8") as f:
                html_content = f.read()
            return HTMLResponse(content=html_content)
        else:
            # HTML de fallback si no existe el archivo
            fallback_html = """
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Generador de Horarios UTB - Móvil</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #093AD3, #4d6ee6);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            border-radius: 15px;
            padding: 30px;
            text-align: center;
            box-shadow: 0 8px 32px rgba(9, 58, 211, 0.2);
            max-width: 400px;
        }
        h1 {
            color: #093AD3;
            margin-bottom: 20px;
            font-size: 24px;
        }
        p {
            color: #666;
            line-height: 1.6;
            margin-bottom: 15px;
        }
        .btn {
            background: linear-gradient(135deg, #093AD3, #4d6ee6);
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            cursor: pointer;
            margin-top: 20px;
            transition: transform 0.2s;
        }
        .btn:hover {
            transform: translateY(-2px);
        }
        .icon {
            font-size: 48px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🎓</div>
        <h1>Generador de Horarios UTB</h1>
        <p><strong>Versión Móvil</strong></p>
        <p>Para una mejor experiencia, recomendamos usar un computador de escritorio.</p>
        <button class="btn" onclick="window.location.reload()">Recargar</button>
    </div>
</body>
</html>
            """
            return HTMLResponse(content=fallback_html)
    else:
        # Para PC, redirigir al Flutter web (puerto 5173 por defecto)
        redirect_html = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Redirigiendo...</title>
    <script>
        window.location.href = 'http://localhost:5173/';
    </script>
</head>
<body>
    <p>Redirigiendo a la versión de escritorio...</p>
</body>
</html>
        """
        return HTMLResponse(content=redirect_html)

@app.get("/device-info")
async def get_device_info(request: Request):
    """
    Endpoint para obtener información del dispositivo (útil para debugging)
    """
    user_agent = request.headers.get("user-agent", "")
    is_mobile = is_mobile_device(user_agent)
    
    return {
        "user_agent": user_agent,
        "is_mobile": is_mobile,
        "device_type": "mobile" if is_mobile else "desktop"
    }

# Endpoints adicionales para servir archivos de la versión móvil
@app.get("/js/{file_path:path}")
async def serve_js_files(file_path: str):
    """Sirve archivos JavaScript de frontend-web"""
    file_location = os.path.join(FRONTEND_WEB_DIR, "js", file_path)
    if os.path.exists(file_location):
        return FileResponse(file_location, media_type="application/javascript")
    raise HTTPException(status_code=404, detail="File not found")

@app.get("/styles/{file_path:path}")
async def serve_css_files(file_path: str):
    """Sirve archivos CSS de frontend-web"""
    file_location = os.path.join(FRONTEND_WEB_DIR, "styles", file_path)
    if os.path.exists(file_location):
        return FileResponse(file_location, media_type="text/css")
    raise HTTPException(status_code=404, detail="File not found")

@app.get("/images/{file_path:path}")
async def serve_image_files(file_path: str):
    """Sirve archivos de imagen de frontend-web"""
    file_location = os.path.join(FRONTEND_WEB_DIR, "images", file_path)
    if os.path.exists(file_location):
        return FileResponse(file_location)
    raise HTTPException(status_code=404, detail="File not found")

@app.get("/api/subjects", summary="Obtener lista de todas las materias")
def get_subjects_list():
    """
    Devuelve una lista ligera de todas las materias disponibles (código, nombre, créditos)
    para ser usada en el buscador del frontend.
    """
    # Llamamos a la función síncrona del repositorio.
    return repository.get_all_subjects_summary()

@app.post("/api/schedules/generate", response_model=List[List[ClassOption]], summary="Generar horarios válidos")
def generate_schedules_endpoint(request: GenerateScheduleRequest):
    """
    Recibe una lista de códigos de materia y un diccionario de filtros.
    
    Ejecuta el algoritmo de backtracking y devuelve una lista de horarios válidos.
    Cada horario es una lista de las opciones de clase que lo componen.
    """
    if not request.subjects:
        raise HTTPException(status_code=400, detail="La lista de materias no puede estar vacía.")

    # 1. Obtener las combinaciones de opciones pre-procesadas desde la BD.
    # Esta función ya no es async.
    combinations = repository.get_combinations_for_subjects(request.subjects)
    
    # Si una de las materias no devuelve combinaciones, el resultado debe ser vacío.
    if not combinations or len(combinations) != len(request.subjects):
        # SOLUCIÓN: Devolver una variable con el tipo explícito.
        empty_result: List[List[ClassOption]] = []
        return empty_result

    # 2. Ejecutar el algoritmo de backtracking con los datos preparados.
    valid_schedules = schedule_generator.find_valid_schedules(
        combinations, request.filters
    )

    # 3. Devolver los resultados.
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
