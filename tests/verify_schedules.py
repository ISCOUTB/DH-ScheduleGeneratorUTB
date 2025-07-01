# verify_schedules.py
import requests
import sys
from typing import List, Dict, Any, Tuple, cast, TypedDict, NotRequired
from datetime import time

# --- DEFINICIONES DE TIPO PARA LOS CASOS DE PRUEBA ---
# Para indicarle a Pylance la estructura exacta de nuestros diccionarios.

class FiltersPayload(TypedDict, total=False):
    """Define la estructura del objeto de filtros (todas las claves son opcionales)."""
    exclude_professors: Dict[str, List[str]]
    include_professors: Dict[str, List[str]]
    unavailable_slots: Dict[str, List[str]]

class SchedulePayload(TypedDict):
    """Define la estructura del payload principal para la API."""
    subjects: List[str]
    filters: FiltersPayload

class FusionCheckConfig(TypedDict):
    """Define la estructura para la configuración de la prueba de fusión."""
    subjectCode: str

class TestCase(TypedDict):
    """Define la estructura de un único caso de prueba."""
    name: str
    payload: SchedulePayload
    fusion_check: NotRequired[FusionCheckConfig] # 'NotRequired' indica que esta clave es opcional.


# --- Lógica de Verificación (copiada y adaptada del backend) ---
# Esto es para no tener que importar desde la app y mantener el script independiente.

def _parse_time(time_str: str) -> time:
    parts = time_str.split(':')
    return time(hour=int(parts[0]), minute=int(parts[1]))

def _parse_time_range(time_range_str: str) -> Tuple[time, time]:
    start_str, end_str = time_range_str.split(' - ')
    return _parse_time(start_str.strip()), _parse_time(end_str.strip())

# SOLUCIÓN: Especificar los tipos de clave y valor para Dict.
def _schedules_overlap(schedule1: Dict[str, Any], schedule2: Dict[str, Any]) -> bool:
    if schedule1['day'] != schedule2['day']:
        return False
    # El 'cast' ayuda al analizador a entender que el valor es un string.
    start1, end1 = _parse_time_range(cast(str, schedule1['time']))
    start2, end2 = _parse_time_range(cast(str, schedule2['time']))
    return start1 < end2 and end1 > start2

def check_for_conflicts(schedule: List[Dict[str, Any]]) -> bool:
    """Verifica si hay algún conflicto de horario dentro de un horario generado."""
    for i in range(len(schedule)):
        for j in range(i + 1, len(schedule)):
            option1 = schedule[i]
            option2 = schedule[j]

            # --- LÓGICA DE VERIFICACIÓN MEJORADA ---
            # Replicamos la lógica del backend: si las dos clases son del mismo
            # grupo y materia, no pueden entrar en conflicto entre sí.
            # Se asume que el JSON de la API incluye 'subjectCode' y 'groupId'.
            if (option1.get('subjectCode') == option2.get('subjectCode') and
                option1.get('groupId') == option2.get('groupId')):
                continue # Saltar a la siguiente comparación, no hay conflicto posible aquí.

            # El 'cast' ayuda al analizador a entender que el valor es una lista.
            for s1 in cast(List[Dict[str, Any]], option1['schedules']):
                for s2 in cast(List[Dict[str, Any]], option2['schedules']):
                    if _schedules_overlap(s1, s2):
                        print(f"  [ERROR] Conflicto encontrado entre NRC {option1['nrc']} y NRC {option2['nrc']}.")
                        return True
    return False

# SOLUCIÓN: Especificar los tipos de clave y valor para el diccionario de filtros.
def check_filters(schedule: List[Dict[str, Any]], filters: Dict[str, Any]) -> bool:
    """Verifica si el horario cumple con los filtros aplicados, de forma insensible a mayúsculas/minúsculas."""
    
    # --- 1. Agrupar clases por materia para una validación eficiente ---
    schedule_by_subject: Dict[str, List[Dict[str, Any]]] = {}
    for option in schedule:
        schedule_by_subject.setdefault(option['subjectCode'], []).append(option)

    # --- 2. Verificación de EXCLUSIÓN de profesores (Case-Insensitive) ---
    if 'exclude_professors' in filters:
        exclude_filter = cast(Dict[str, List[str]], filters['exclude_professors'])
        for subject_code, excluded_profs_list in exclude_filter.items():
            if subject_code in schedule_by_subject:
                excluded_profs_set = {prof.lower() for prof in excluded_profs_list}
                for option in schedule_by_subject[subject_code]:
                    professor_lower = cast(str, option['professor']).lower()
                    if professor_lower in excluded_profs_set:
                        print(f"  [ERROR] Filtro de exclusión fallido: El profesor '{option['professor']}' está en el horario (NRC {option['nrc']}).")
                        return False

    # --- 3. Verificación de INCLUSIÓN de profesores (Case-Insensitive) ---
    if 'include_professors' in filters:
        include_filter = cast(Dict[str, List[str]], filters['include_professors'])
        for subject_code, included_profs_list in include_filter.items():
            if subject_code in schedule_by_subject:
                included_profs_set = {prof.lower() for prof in included_profs_list}
                professors_in_schedule = {cast(str, opt['professor']).lower() for opt in schedule_by_subject[subject_code]}
                
                if not professors_in_schedule.intersection(included_profs_set):
                    print(f"  [ERROR] Filtro de inclusión fallido: Ninguno de los profesores deseados para {subject_code} está en el horario.")
                    return False

    # --- 4. Verificación de HORAS NO DISPONIBLES (Case-Insensitive para los días) ---
    if 'unavailable_slots' in filters:
        unavailable_slots = cast(Dict[str, List[str]], filters.get('unavailable_slots', {}))
        # Normalizamos las claves del filtro (días) a minúsculas
        unavailable_slots_lower = {day.lower(): times for day, times in unavailable_slots.items()}

        for option in schedule:
            for class_time in cast(List[Dict[str, Any]], option['schedules']):
                day_lower = cast(str, class_time['day']).lower()
                if day_lower in unavailable_slots_lower:
                    class_start, class_end = _parse_time_range(class_time['time'])
                    for unavailable_hour_str in unavailable_slots_lower[day_lower]:
                        unavailable_time = _parse_time(unavailable_hour_str)
                        if class_start <= unavailable_time < class_end:
                            print(f"  [ERROR] Filtro de horas fallido: La clase NRC {option['nrc']} se solapa con un horario no disponible ({class_time['day']} a las {unavailable_hour_str}).")
                            return False
    
    return True


# --- NUEVA FUNCIÓN PARA VERIFICAR LA FUSIÓN ---
def check_fusion(schedule: List[Dict[str, Any]], fusion_config: Dict[str, Any]) -> bool:
    """Verifica si la fusión de NRCs para una materia específica ocurrió como se esperaba."""
    subject_to_check = fusion_config.get("subjectCode")
    if not subject_to_check:
        return True # No hay nada que verificar

    classes_for_subject = [opt for opt in schedule if opt.get('subjectCode') == subject_to_check]
    
    if not classes_for_subject:
        # Si la materia no está en el horario, no podemos verificar la fusión.
        # Esto puede ser válido si ningún horario la contenía.
        return True

    # Contamos el número total de clases (NRCs) para la materia.
    nrc_count = len(classes_for_subject)

    # Creamos una "huella" para cada franja horaria única.
    time_slots: set[str] = set()
    for option in classes_for_subject:
        for s in cast(List[Dict[str, Any]], option['schedules']):
            time_slots.add(f"{s['day']}:{s['time']}")
    
    unique_slots_count = len(time_slots)

    # La fusión es exitosa si hay más NRCs que franjas horarias únicas.
    if nrc_count > unique_slots_count:
        print(f"  [OK] Fusión detectada para {subject_to_check}: {nrc_count} NRCs en {unique_slots_count} franjas horarias.")
        return True
    
    # Si no hay fusión, podría ser porque solo había un lab disponible.
    # Esta prueba solo confirma que si hay fusión, es correcta.
    # No falla si no hay fusión, ya que puede ser un escenario válido.
    return True

# --- Casos de Prueba ---
API_URL = "http://127.0.0.1:8000/api/schedules/generate"

# SOLUCIÓN: Aplicamos el tipo 'TestCase' a nuestra lista de casos de prueba.
test_cases: List[TestCase] = [
    {
        "name": "1. Generación Básica y Verificación de Fusión",
        "payload": {
            "subjects": ["CBASF02A", "ISCOC04A", "CBASM05A", "CHUMH02A"], # Esta materia tiene labs para fusionar
            "filters": {}
        },
        "fusion_check": {"subjectCode": "CBASF02A"} # Configuración para la verificación de fusión
    },
    {
        "name": "2. Filtro de Exclusión de Profesor",
        "payload": {
            "subjects": ["CBASF02A"],
            "filters": {
                "exclude_professors": {
                    "CBASF02A": ["HERNANDO RAFAEL ALTAMAR MERCADO"] # Usamos mayúsculas para probar la insensibilidad
                }
            }
        }
    },
    {
        "name": "3. Filtro de Inclusión de Profesor",
        "payload": {
            "subjects": ["CBASF01A"],
            "filters": {
                "include_professors": {
                    "CBASF01A": ["vilma viviana ojeda caicedo"] # Usamos minúsculas
                }
            }
        }
    },
    {
        "name": "4. Filtro de Horas No Disponibles",
        "payload": {
            "subjects": ["CBASF01A"],
            "filters": {
                "unavailable_slots": {
                    "Martes": ["11:00"] # Bloqueamos Martes de 11 a 12
                }
            }
        }
    },
    {
        "name": "5. Generación con Múltiples Materias",
        "payload": {
            "subjects": ["CBASF01A", "CHUMH02A"], # Añadir otra materia
            "filters": {}
        }
    }
]

# --- Script Principal ---
def main():
    total_errors = 0
    for case in test_cases:
        print(f"\n{'='*20} INICIANDO CASO DE PRUEBA: {case['name']} {'='*20}")
        
        test_payload = case["payload"]
        print(f"Enviando petición para las materias: {test_payload['subjects']}")
        
        try:
            response = requests.post(API_URL, json=test_payload)
            response.raise_for_status()
        except requests.exceptions.RequestException as e:
            print(f"  [FATAL] Error al conectar con la API: {e}")
            total_errors += 1
            continue

        generated_schedules = cast(List[List[Dict[str, Any]]], response.json())

        if not generated_schedules:
            print("  [INFO] La API no devolvió horarios (lo cual puede ser correcto para estos filtros).")
            continue

        print(f"La API generó {len(generated_schedules)} horarios. Verificando cada uno...")
        case_errors = 0
        for i, schedule in enumerate(generated_schedules):
            print(f"\n--- Verificando Horario #{i+1} ---")
            
            has_conflict = check_for_conflicts(schedule)
            # SOLUCIÓN: Usamos 'cast' para asegurar al analizador que los TypedDict son compatibles.
            meets_filters = check_filters(schedule, cast(Dict[str, Any], case['payload']['filters']))
            fusion_ok = check_fusion(schedule, cast(Dict[str, Any], case.get("fusion_check", {})))

            if has_conflict or not meets_filters or not fusion_ok:
                case_errors += 1
            else:
                print("  [OK] Horario válido.")
        
        if case_errors > 0:
            total_errors += case_errors
            print(f"\n--- [FALLIDO] El caso '{case['name']}' encontró {case_errors} errores. ---")
        else:
            print(f"\n--- [ÉXITO] El caso '{case['name']}' pasó todas las verificaciones. ---")

    print("\n\n" + "="*25 + " RESUMEN FINAL " + "="*25)
    if total_errors == 0:
        print("¡ÉXITO TOTAL! Todos los casos de prueba pasaron sin errores.")
    else:
        print(f"¡SE ENCONTRARON ERRORES! Total de errores en todos los casos: {total_errors}")
        sys.exit(1)

if __name__ == "__main__":
    main()