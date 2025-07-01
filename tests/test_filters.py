import requests
# SOLUCIÓN: Se elimina la importación de pytest ya que no se usa directamente.
# Se importa Dict y Any para las anotaciones de tipo.
from typing import Dict, Any

API_URL = "http://127.0.0.1:8000/api/schedules/generate"

def test_filter_exclude_professor():
    """
    Verifica que el filtro 'exclude_professors' elimina correctamente
    las opciones de un profesor específico.
    """
    professor_to_exclude = "Vilma Viviana Ojeda Caicedo"
    subject_code = "CBASF01A" # Física Mecánica tiene varias opciones de profesor

    # SOLUCIÓN: Añadir una anotación de tipo explícita.
    payload: Dict[str, Any] = {
        "subjects": [subject_code],
        "filters": {
            "exclude_professors": {
                subject_code: [professor_to_exclude]
            }
        }
    }
    
    response = requests.post(API_URL, json=payload)
    response.raise_for_status()
    schedules = response.json()

    assert len(schedules) > 0, "No se generaron horarios, la prueba no puede continuar."

    for schedule in schedules:
        for class_option in schedule:
            if class_option['subjectCode'] == subject_code:
                assert class_option['professor'] != professor_to_exclude, \
                    f"Error: Se encontró un horario con el profesor excluido '{professor_to_exclude}'"

def test_filter_include_professor():
    """
    Verifica que el filtro 'include_professors' genera horarios
    únicamente con el profesor especificado.
    """
    professor_to_include = "Pablo Gustavo Abitbol Piñeiro"
    # Usamos las nuevas materias que solo él dicta en este conjunto
    subjects = ["CPOLN03A", "CPOLN05A"]

    # SOLUCIÓN: Añadir una anotación de tipo explícita.
    payload: Dict[str, Any] = {
        "subjects": subjects,
        "filters": {
            "include_professors": {
                "CPOLN03A": [professor_to_include],
                "CPOLN05A": [professor_to_include]
            }
        }
    }

    response = requests.post(API_URL, json=payload)
    response.raise_for_status()
    schedules = response.json()

    assert len(schedules) > 0, "No se generaron horarios, la prueba no puede continuar."

    for schedule in schedules:
        for class_option in schedule:
            assert class_option['professor'] == professor_to_include, \
                f"Error: Se encontró un horario con un profesor no incluido. Se esperaba a '{professor_to_include}'."

def test_filter_unavailable_slots():
    """
    Verifica que el filtro 'unavailable_slots' reduce el número de
    horarios posibles al bloquear un espacio de tiempo.
    """
    subjects = ["CPOLN05A", "CPOLE12A"] # Filosofía y Seguridad
    
    # Escenario 1: Sin filtro
    # SOLUCIÓN: Añadir una anotación de tipo explícita.
    payload_no_filter: Dict[str, Any] = {"subjects": subjects, "filters": {}}
    response_no_filter = requests.post(API_URL, json=payload_no_filter)
    response_no_filter.raise_for_status()
    count_no_filter = len(response_no_filter.json())

    # Escenario 2: Con filtro que causa conflicto
    # Filosofía es Miércoles 13:00-14:50. Lo bloqueamos.
    # SOLUCIÓN: Añadir una anotación de tipo explícita.
    payload_with_filter: Dict[str, Any] = {
        "subjects": subjects,
        "filters": {
            "unavailable_slots": {
                "Miércoles": ["13:00"]
            }
        }
    }
    response_with_filter = requests.post(API_URL, json=payload_with_filter)
    response_with_filter.raise_for_status()
    count_with_filter = len(response_with_filter.json())

    # La única combinación posible debería ser eliminada.
    assert count_with_filter == 0, \
        f"Se esperaba que el filtro eliminara todas las combinaciones, pero se encontraron {count_with_filter}."
    assert count_with_filter < count_no_filter, \
        "El filtro de horas no disponibles no tuvo efecto en el número de horarios generados."