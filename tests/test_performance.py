import requests
import time
import pytest
# SOLUCIÓN: Importar los tipos necesarios
from typing import Dict, Any

API_URL = "http://127.0.0.1:8000/api/schedules/generate"

# --- Escenarios de Carga ---

# 1. Carga Típica: Un estudiante promedio (3 materias)
# SOLUCIÓN: Añadir una anotación de tipo explícita
PAYLOAD_TYPICAL: Dict[str, Any] = {
    "subjects": ["CBASF03A", "CHUMA07A", "ISCOC04A"],
    "filters": {}
}

# 2. Carga Alta: Un estudiante con una carga académica pesada (6 materias)
# SOLUCIÓN: Añadir una anotación de tipo explícita
PAYLOAD_HIGH: Dict[str, Any] = {
    "subjects": [
        "CBASF03A", "CHUMA07A", "ISCOC04A",
        "CBASM05A", "CHUMH02A", "CBASF02A"
    ],
    "filters": {}
}

# 3. Carga Muy Alta: Usando las nuevas materias (10 materias)
# SOLUCIÓN: Añadir una anotación de tipo explícita
PAYLOAD_VERY_HIGH: Dict[str, Any] = {
    "subjects": [
        "CBASF03A", "CHUMA07A", "ISCOC04A", "CBASM05A",
        "CHUMH02A", "CBASF02A", "CPOLE12A", "CPOLN03A",
        "CPOLN05A", "CPOLN07A"
    ],
    "filters": {}
}


# --- Umbrales de Rendimiento (en segundos) ---
PERFORMANCE_THRESHOLD_TYPICAL = 5.0
PERFORMANCE_THRESHOLD_HIGH = 15.0
PERFORMANCE_THRESHOLD_VERY_HIGH = 45.0 # Damos más tiempo para la carga extrema

# --- Pruebas de Rendimiento con Pytest ---

def test_performance_typical_load():
    """
    Mide el tiempo de respuesta de la API para una carga de trabajo típica.
    """
    print(f"\nIniciando prueba de rendimiento con carga TÍPICA ({len(PAYLOAD_TYPICAL['subjects'])} materias)...")
    
    start_time = time.time()
    try:
        response = requests.post(API_URL, json=PAYLOAD_TYPICAL, timeout=PERFORMANCE_THRESHOLD_TYPICAL + 5)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        pytest.fail(f"La petición a la API falló: {e}")
    
    end_time = time.time()
    duration = end_time - start_time
    
    print(f"Duración de la prueba TÍPICA: {duration:.4f} segundos.")
    
    assert duration < PERFORMANCE_THRESHOLD_TYPICAL, \
        f"La prueba de carga típica excedió el umbral de {PERFORMANCE_THRESHOLD_TYPICAL}s (tardó {duration:.4f}s)"

def test_performance_high_load():
    """
    Mide el tiempo de respuesta de la API para una carga de trabajo alta.
    """
    print(f"\nIniciando prueba de rendimiento con carga ALTA ({len(PAYLOAD_HIGH['subjects'])} materias)...")
    
    start_time = time.time()
    try:
        response = requests.post(API_URL, json=PAYLOAD_HIGH, timeout=PERFORMANCE_THRESHOLD_HIGH + 5)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        pytest.fail(f"La petición a la API falló: {e}")
        
    end_time = time.time()
    duration = end_time - start_time
    
    print(f"Duración de la prueba ALTA: {duration:.4f} segundos.")
    
    assert duration < PERFORMANCE_THRESHOLD_HIGH, \
        f"La prueba de carga alta excedió el umbral de {PERFORMANCE_THRESHOLD_HIGH}s (tardó {duration:.4f}s)"

def test_performance_very_high_load():
    """
    Mide el tiempo de respuesta de la API para una carga de trabajo muy alta.
    """
    print(f"\nIniciando prueba de rendimiento con carga MUY ALTA ({len(PAYLOAD_VERY_HIGH['subjects'])} materias)...")
    
    start_time = time.time()
    try:
        response = requests.post(API_URL, json=PAYLOAD_VERY_HIGH, timeout=PERFORMANCE_THRESHOLD_VERY_HIGH + 5)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        pytest.fail(f"La petición a la API falló: {e}")
        
    end_time = time.time()
    duration = end_time - start_time
    
    print(f"Duración de la prueba MUY ALTA: {duration:.4f} segundos.")
    
    assert duration < PERFORMANCE_THRESHOLD_VERY_HIGH, \
        f"La prueba de carga muy alta excedió el umbral de {PERFORMANCE_THRESHOLD_VERY_HIGH}s (tardó {duration:.4f}s)"
