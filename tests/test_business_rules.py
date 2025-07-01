import requests
from typing import Dict, Any, List

API_URL = "http://127.0.0.1:8000/api/schedules/generate"

def test_credit_limit_respected():
    """
    Verifica que el filtro 'max_credits' y el límite por defecto funcionan.
    Prueba que para un conjunto de 20 créditos, se pueden generar horarios
    con un límite explícito de 20 o con el límite por defecto (20), pero no
    con un límite explícito de 18.
    """
    # 1. Definir un conjunto de materias cuya suma de créditos es 20.
    subjects_20_credits = [
        "ISCOC02A", "CBASM03A", "CBASF01A",
        "CHUMH02A", "CBASM04A", "ISCOC04A"
    ]

    # 2. Escenario A: Límite explícito de 18 créditos (debería fallar).
    print("\nProbando con límite explícito de 18 créditos (esperado: 0 horarios)...")
    payload_limit_18: Dict[str, Any] = {
        "subjects": subjects_20_credits,
        "filters": {"max_credits": 18}
    }
    response_limit_18 = requests.post(API_URL, json=payload_limit_18)
    response_limit_18.raise_for_status()
    schedules_limit_18 = response_limit_18.json()

    assert len(schedules_limit_18) == 0, \
        f"Error: Se encontraron {len(schedules_limit_18)} horarios cuando se esperaba 0 con un límite de 18 créditos."
    print("Prueba con límite de 18 créditos exitosa.")

    # 3. Escenario B: Límite explícito de 20 créditos (debería tener éxito).
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

    # SOLUCIÓN: 4. Escenario C: Sin límite explícito, usando el default del backend.
    print("\nProbando con límite por defecto del backend (20) (esperado: >0 horarios)...")
    payload_default_limit: Dict[str, Any] = {
        "subjects": subjects_20_credits,
        "filters": {} # No se envía 'max_credits' para probar el default.
    }
    response_default = requests.post(API_URL, json=payload_default_limit)
    response_default.raise_for_status()
    schedules_default = response_default.json()

    assert len(schedules_default) > 0, \
        "Error: No se encontró ningún horario usando el límite por defecto del backend."
    
    # Verificación adicional: que ningún horario generado exceda el límite por defecto.
    for schedule in schedules_default:
        # Se asume que los créditos de una materia son los de su primer componente.
        # Para un cálculo preciso, se deben sumar los créditos de materias únicas.
        # SOLUCIÓN: Cambiar el acceso de atributo (opt.subject_code) a acceso por clave (opt['subjectCode']).
        unique_subjects = {opt['subjectCode']: opt['credits'] for opt in schedule}
        total_credits = sum(unique_subjects.values())
        assert total_credits <= 20, \
            f"Error: Se generó un horario con {total_credits} créditos, excediendo el límite por defecto de 20."
    
    print(f"Prueba con límite por defecto exitosa. Se encontraron {len(schedules_default)} horarios válidos.")


def test_group_coherence():
    """
    Verifica que para materias con Teórico y Laboratorio, el algoritmo
    siempre selecciona componentes del mismo 'groupId'.
    """
    # Física Mecánica (CBASF01A) tiene múltiples grupos con teóricas y laboratorios.
    subjects = ["CBASF01A", "CBASM03A"] # Física y Cálculo Integral

    payload: Dict[str, Any] = {"subjects": subjects, "filters": {}}
    response = requests.post(API_URL, json=payload)
    response.raise_for_status()
    schedules = response.json()

    assert len(schedules) > 0, "No se generaron horarios, la prueba no puede continuar."

    for schedule in schedules:
        # Agrupar las clases por materia
        classes_by_subject: Dict[str, List[Dict[str, Any]]] = {}
        for class_option in schedule:
            code = class_option['subjectCode']
            if code not in classes_by_subject:
                classes_by_subject[code] = []
            classes_by_subject[code].append(class_option)
        
        # Para cada materia en el horario, verificar la coherencia de grupo
        for subject_code, classes in classes_by_subject.items():
            if len(classes) > 1: # Si hay más de un componente (ej. Teórico y Lab)
                first_group_id = classes[0]['groupId']
                for class_option in classes[1:]:
                    assert class_option['groupId'] == first_group_id, \
                        f"Error de coherencia: La materia {subject_code} tiene clases de diferentes grupos ({first_group_id} y {class_option['groupId']})."
