"""
Pruebas de integración para las reglas de negocio del API de generación de horarios.

Este módulo valida la lógica central del endpoint, asegurando que los filtros
y las restricciones implícitas (como la coherencia de grupos) se apliquen
correctamente sobre los datos reales.
"""
import requests
from typing import Dict, Any, List

# URL del endpoint de la API a probar.
API_URL = "http://127.0.0.1:8000/api/schedules/generate"

def test_credit_limit_respected():
    """
    Valida la correcta aplicación del filtro 'max_credits' y el límite por defecto.

    Comprueba que para un conjunto de materias que suman 20 créditos, la API:
    1. No retorna resultados si el límite es inferior (18).
    2. Retorna resultados si el límite es igual (20).
    3. Aplica correctamente el límite por defecto del backend (asumido en 20).
    """
    # Define un conjunto de materias cuya suma de créditos es 20.
    subjects_20_credits = [
        "ISCOC02A", "CBASM03A", "CBASF01A",
        "CHUMH02A", "CBASM04A", "ISCOC04A"
    ]

    # Escenario 1: Límite de créditos inferior al total. Se esperan 0 horarios.
    print("\nProbando con límite explícito de 18 créditos (esperado: 0 horarios)...")
    payload_limit_18: Dict[str, Any] = {
        "subjects": subjects_20_credits,
        "filters": {"max_credits": 18}
    }
    response_limit_18 = requests.post(API_URL, json=payload_limit_18)
    response_limit_18.raise_for_status() # Asegura que la petición fue exitosa (código 2xx).
    schedules_limit_18 = response_limit_18.json()

    assert len(schedules_limit_18) == 0, \
        f"Error: Se encontraron {len(schedules_limit_18)} horarios cuando se esperaba 0 con un límite de 18 créditos."
    print("Prueba con límite de 18 créditos exitosa.")

    # Escenario 2: Límite de créditos igual al total. Se esperan resultados.
    print("\nProbando con límite explícito de 20 créditos (esperado: >0 horarios)...")
    payload_limit_20: Dict[str, Any] = {
        "subjects": subjects_20_credits,
        "filters": {"max_credits": 20}
    }
    response_limit_20 = requests.post(API_URL, json=payload_limit_20)
    response_limit_20.raise_for_status()
    schedules_limit_20 = response_limit_20.json()

    assert len(schedules_limit_20) > 0, \
        "Error: No se encontró ningún horario con un límite explícito de 20 créditos."
    print(f"Prueba con límite explícito de 20 créditos exitosa. Se encontraron {len(schedules_limit_20)} horarios.")

    # Escenario 3: Sin filtro explícito para probar el límite por defecto del backend.
    print("\nProbando con límite por defecto del backend (20) (esperado: >0 horarios)...")
    payload_default_limit: Dict[str, Any] = {
        "subjects": subjects_20_credits,
        "filters": {} # No se envía 'max_credits'.
    }
    response_default = requests.post(API_URL, json=payload_default_limit)
    response_default.raise_for_status()
    schedules_default = response_default.json()

    assert len(schedules_default) > 0, \
        "Error: No se encontró ningún horario usando el límite por defecto del backend."
    
    # Verificación adicional: cada horario generado no debe superar el límite.
    for schedule in schedules_default:
        # Se calcula el total de créditos sumando los de materias únicas para evitar duplicados.
        unique_subjects = {opt['subjectCode']: opt['credits'] for opt in schedule}
        total_credits = sum(unique_subjects.values())
        assert total_credits <= 20, \
            f"Error: Se generó un horario con {total_credits} créditos, excediendo el límite por defecto de 20."
    
    print(f"Prueba con límite por defecto exitosa. Se encontraron {len(schedules_default)} horarios válidos.")


def test_group_coherence():
    """
    Verifica que para materias con múltiples componentes (ej. Teórico y Laboratorio),
    el algoritmo siempre selecciona componentes del mismo 'groupId'.
    """
    # Se usa una materia con componentes teóricos y prácticos en diferentes grupos.
    subjects = ["CBASF01A", "CBASM03A"] # Física Mecánica y Cálculo Integral

    payload: Dict[str, Any] = {"subjects": subjects, "filters": {}}
    response = requests.post(API_URL, json=payload)
    response.raise_for_status()
    schedules = response.json()

    assert len(schedules) > 0, "No se generaron horarios, la prueba no puede continuar."

    # Itera sobre cada horario para validar la coherencia de grupo.
    for schedule in schedules:
        # Agrupa las clases por código de materia para analizarlas.
        classes_by_subject: Dict[str, List[Dict[str, Any]]] = {}
        for class_option in schedule:
            code = class_option['subjectCode']
            if code not in classes_by_subject:
                classes_by_subject[code] = []
            classes_by_subject[code].append(class_option)
        
        # Para cada materia, si tiene más de un componente, todos deben tener el mismo groupId.
        for subject_code, classes in classes_by_subject.items():
            if len(classes) > 1:
                first_group_id = classes[0]['groupId']
                for class_option in classes[1:]:
                    assert class_option['groupId'] == first_group_id, \
                        f"Error de coherencia: La materia {subject_code} tiene clases de diferentes grupos ({first_group_id} y {class_option['groupId']})."
