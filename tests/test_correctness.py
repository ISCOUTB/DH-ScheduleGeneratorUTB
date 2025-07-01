from typing import List, Dict, Any

# Se asume que es posible importar la lógica del generador.
# Al ejecutar con 'pytest' desde la raíz, esto suele manejarse automáticamente.
from backend.app.services.schedule_generator import find_valid_schedules
from backend.app.models import ClassOption, Schedule

# --- FUNCIÓN DE AYUDA PARA REDUCIR LA REPETICIÓN ---
def create_class_group(
    base_info: Dict[str, Any],
    # SOLUCIÓN: Corregir el tipo para que refleje la lista de listas.
    options: List[List[Dict[str, Any]]]
) -> List[List[ClassOption]]:
    """Crea una lista de opciones de clase para una materia, reduciendo el código repetido."""
    class_groups: List[List[ClassOption]] = []
    for opt in options:
        group: List[ClassOption] = []
        for nrc_info in opt:
            group.append(ClassOption(
                subjectCode=base_info["code"],
                subjectName=base_info["name"],
                credits=base_info["credits"],
                type=nrc_info["type"],
                professor=nrc_info["professor"],
                nrc=nrc_info["nrc"],
                groupId=nrc_info["groupId"],
                schedules=[Schedule(**s) for s in nrc_info["schedules"]]
            ))
        class_groups.append(group)
    return class_groups

# --- "Golden Dataset" (Basado en tus datos) ---

# 1. Física Calor Y Ondas (CBASF03A)
# SOLUCIÓN: Añadir un tipo explícito al diccionario base.
fisica_base: Dict[str, Any] = {"code": "CBASF03A", "name": "Física Calor Y Ondas", "credits": 4}
fisica_options = create_class_group(fisica_base, [
    [ # Grupo 1
        {"type": "Teórico", "professor": "Jorge Luis Muñiz Olite", "nrc": "1001", "groupId": 1, "schedules": [{"day": "Miércoles", "time": "13:00 - 14:50"}, {"day": "Viernes", "time": "14:00 - 15:50"}]},
        {"type": "Laboratorio", "professor": "Gabriel Andres Hoyos Gomez Casseres", "nrc": "1002", "groupId": 1, "schedules": [{"day": "Lunes", "time": "09:00 - 10:50"}]}
    ],
    [ # Grupo 2
        {"type": "Teórico", "professor": "Alberto Patiño Vanegas", "nrc": "1007", "groupId": 2, "schedules": [{"day": "Jueves", "time": "07:00 - 08:50"}, {"day": "Viernes", "time": "13:00 - 14:50"}]},
        {"type": "Laboratorio", "professor": "Alexander De Jesus Leyton Coneo", "nrc": "1008", "groupId": 2, "schedules": [{"day": "Miércoles", "time": "15:00 - 16:50"}]}
    ],
    [ # Grupo 3
        {"type": "Teórico", "professor": "Alberto Patiño Vanegas", "nrc": "1018", "groupId": 3, "schedules": [{"day": "Martes", "time": "07:00 - 08:50"}, {"day": "Viernes", "time": "15:00 - 16:50"}]},
        {"type": "Laboratorio", "professor": "Kevin David Mendoza Vanegas", "nrc": "2656", "groupId": 3, "schedules": [{"day": "Jueves", "time": "07:00 - 08:50"}]}
    ]
])

# 2. Fotografía Creativa (CHUMA07A)
foto_base: Dict[str, Any] = {"code": "CHUMA07A", "name": "Fotografía Creativa", "credits": 2}
foto_options = create_class_group(foto_base, [
    [{"type": "Teórico", "professor": "Lissette Del Rosario Urquijo Burgos", "nrc": "2162", "groupId": 1, "schedules": [{"day": "Martes", "time": "11:00 - 12:50"}]}],
    [{"type": "Teórico", "professor": "Lissette Del Rosario Urquijo Burgos", "nrc": "2163", "groupId": 1, "schedules": [{"day": "Miércoles", "time": "13:00 - 14:50"}]}]
])

# 3. Programación Orientada A Objet (ISCOC04A)
poo_base: Dict[str, Any] = {"code": "ISCOC04A", "name": "Programación Orientada A Objet", "credits": 3}
poo_options = create_class_group(poo_base, [
    [{"type": "Teórico", "professor": "Carlos Ernesto Botero Pareja", "nrc": "2221", "groupId": 1, "schedules": [{"day": "Jueves", "time": "16:00 - 16:50"}, {"day": "Miércoles", "time": "13:00 - 14:50"}]}],
    [{"type": "Teórico", "professor": "Yuranis Henriquez Nuñez", "nrc": "2236", "groupId": 1, "schedules": [{"day": "Lunes", "time": "07:00 - 07:50"}, {"day": "Viernes", "time": "08:00 - 09:50"}]}]
])

# --- Caso de Prueba para Pytest ---

def test_backtracking_correctness_real_data():
    """
    Verifica que el algoritmo de backtracking genere el número exacto de horarios
    válidos para un conjunto de datos real y complejo.
    """
    # Combinamos las opciones de las 3 materias
    all_combinations = [fisica_options, foto_options, poo_options]
    
    # El número esperado de horarios válidos después del análisis manual es 7.
    EXPECTED_COUNT = 7

    # Ejecutamos el algoritmo
    schedules = find_valid_schedules(all_combinations, {})

    # Afirmamos que el resultado es el esperado
    assert len(schedules) == EXPECTED_COUNT, \
        f"Se esperaban {EXPECTED_COUNT} horarios, pero se generaron {len(schedules)}"

