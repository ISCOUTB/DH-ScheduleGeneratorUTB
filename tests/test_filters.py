import requests
# Se importa Dict y Any para las anotaciones de tipo.
from typing import Dict, Any

# URL base del endpoint para las pruebas de integración.
API_URL = "http://127.0.0.1:8000/api/schedules/generate"

def test_filter_exclude_professor():
    """
    Verifica que el filtro 'exclude_professors' elimina correctamente
    las opciones de un profesor específico.
    """
    # Define el profesor a excluir y la materia afectada.
    professor_to_exclude = "Vilma Viviana Ojeda Caicedo"
    subject_code = "CBASF01A" # Física Mecánica tiene varias opciones de profesor

    # Construye el payload para la API, especificando el filtro de exclusión.
    payload: Dict[str, Any] = {
        "subjects": [subject_code],
        "filters": {
            "exclude_professors": {
                subject_code: [professor_to_exclude]
            }
        }
    }
    
    # Realiza la petición POST al endpoint.
    response = requests.post(API_URL, json=payload)
    response.raise_for_status()
    schedules = response.json()

    assert len(schedules) > 0, "No se generaron horarios, la prueba no puede continuar."

    # Itera sobre los resultados para asegurar que el profesor excluido no está presente.
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
    # Define el profesor a incluir y las materias que imparte.
    professor_to_include = "Pablo Gustavo Abitbol Piñeiro"
    subjects = ["CPOLN03A", "CPOLN05A"]

    # Construye el payload, indicando que solo se consideren las clases de este profesor.
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

    # Verifica que todas las clases en los horarios generados pertenezcan al profesor incluido.
    for schedule in schedules:
        for class_option in schedule:
            assert class_option['professor'] == professor_to_include, \
                f"Error: Se encontró un horario con un profesor no incluido. Se esperaba a '{professor_to_include}'."

def test_filter_unavailable_slots():
    """
    Verifica que el filtro 'unavailable_slots' reduce el número de
    horarios posibles al bloquear un espacio de tiempo.
    """
    # Define las materias para la prueba.
    subjects = ["CPOLN05A", "CPOLE12A"] # Filosofía y Seguridad
    
    # Escenario 1: Petición sin filtros para obtener el número total de horarios posibles.
    payload_no_filter: Dict[str, Any] = {"subjects": subjects, "filters": {}}
    response_no_filter = requests.post(API_URL, json=payload_no_filter)
    response_no_filter.raise_for_status()
    count_no_filter = len(response_no_filter.json())

    # Escenario 2: Petición con un filtro que bloquea una franja horaria clave.
    # El filtro bloquea la franja de "Miércoles" a las "13:00", que entra en conflicto con una de las materias.
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

    # Se espera que el filtro elimine la única combinación posible.
    assert count_with_filter == 0, \
        f"Se esperaba que el filtro eliminara todas las combinaciones, pero se encontraron {count_with_filter}."
    # Se verifica que el número de horarios con filtro es menor que sin filtro.
    assert count_with_filter < count_no_filter, \
        "El filtro de horas no disponibles no tuvo efecto en el número de horarios generados."