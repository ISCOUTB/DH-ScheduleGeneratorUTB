"""
Prueba unitaria para el algoritmo de backtracking 'find_valid_schedules'.

Este módulo verifica la correctitud del algoritmo de generación de horarios
utilizando un "Golden Dataset", un conjunto de datos de entrada fijo y conocido
cuyo resultado esperado ha sido precalculado. El objetivo es asegurar que la
lógica central produce el número exacto de combinaciones válidas, sirviendo
como una prueba de regresión.
"""
from typing import List, Dict, Any

# Se importa la lógica del generador y los modelos de datos necesarios para la prueba.
from backend.app.services.schedule_generator import find_valid_schedules
from backend.app.models import ClassOption, Schedule

# --- FUNCIÓN DE AYUDA PARA LA CREACIÓN DE DATOS DE PRUEBA ---
def create_class_group(
    base_info: Dict[str, Any],
    options: List[List[Dict[str, Any]]]
) -> List[List[ClassOption]]:
    """
    Función de fábrica (factory) para construir la estructura de datos de una materia.
    
    Toma información base de una materia y una lista de sus grupos/opciones para
    instanciar los objetos 'ClassOption' y 'Schedule' correspondientes. Su propósito
    es reducir la verbosidad y la repetición en la definición del dataset de prueba.
    """
    class_groups: List[List[ClassOption]] = []
    for opt in options:
        group: List[ClassOption] = []
        for nrc_info in opt:
            # Instancia un objeto ClassOption a partir de un diccionario.
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

# --- "Golden Dataset": Conjunto de datos de entrada para la prueba ---
# Este dataset representa un escenario real y complejo con un resultado conocido.

# 1. Definición de la materia "Física Calor Y Ondas" con 3 grupos de opciones.
fisica_base: Dict[str, Any] = {"code": "CBASF03A", "name": "Física Calor Y Ondas", "credits": 4}
fisica_options = create_class_group(fisica_base, [
    [ # Grupo 1: Componente teórico y de laboratorio.
        {"type": "Teórico", "professor": "Jorge Luis Muñiz Olite", "nrc": "1001", "groupId": 1, "schedules": [{"day": "Miércoles", "time": "13:00 - 14:50"}, {"day": "Viernes", "time": "14:00 - 15:50"}]},
        {"type": "Laboratorio", "professor": "Gabriel Andres Hoyos Gomez Casseres", "nrc": "1002", "groupId": 1, "schedules": [{"day": "Lunes", "time": "09:00 - 10:50"}]}
    ],
    [ # Grupo 2
        {"type": "Teórico", "professor": "Alberto Patiño Vanegas", "nrc": "1007", "groupId": 2, "schedules": [{"day": "Jueves", "time": "07:00 - 08:50"}, {"day": "Viernes", "time": "13:00 - 14:50"}]},
        {"type": "Laboratorio", "professor": "Alexander De Jesus Leyton Coneo", "nrc": "1008", "groupId": 2, "schedules": [{"day": "Miércoles", "time": "15:00 - 16:50"}]}
    ],
    [ # Grupo 3: Este grupo causa un conflicto de horario con el grupo 2 de POO.
        {"type": "Teórico", "professor": "Alberto Patiño Vanegas", "nrc": "1018", "groupId": 3, "schedules": [{"day": "Martes", "time": "07:00 - 08:50"}, {"day": "Viernes", "time": "15:00 - 16:50"}]},
        {"type": "Laboratorio", "professor": "Kevin David Mendoza Vanegas", "nrc": "2656", "groupId": 3, "schedules": [{"day": "Jueves", "time": "07:00 - 08:50"}]}
    ]
])

# 2. Definición de "Fotografía Creativa" con 2 opciones de un solo componente.
foto_base: Dict[str, Any] = {"code": "CHUMA07A", "name": "Fotografía Creativa", "credits": 2}
foto_options = create_class_group(foto_base, [
    [{"type": "Teórico", "professor": "Lissette Del Rosario Urquijo Burgos", "nrc": "2162", "groupId": 1, "schedules": [{"day": "Martes", "time": "11:00 - 12:50"}]}],
    [{"type": "Teórico", "professor": "Lissette Del Rosario Urquijo Burgos", "nrc": "2163", "groupId": 1, "schedules": [{"day": "Miércoles", "time": "13:00 - 14:50"}]}]
])

# 3. Definición de "Programación Orientada A Objetos" con 2 opciones.
poo_base: Dict[str, Any] = {"code": "ISCOC04A", "name": "Programación Orientada A Objet", "credits": 3}
poo_options = create_class_group(poo_base, [
    [{"type": "Teórico", "professor": "Carlos Ernesto Botero Pareja", "nrc": "2221", "groupId": 1, "schedules": [{"day": "Jueves", "time": "16:00 - 16:50"}, {"day": "Miércoles", "time": "13:00 - 14:50"}]}],
    [{"type": "Teórico", "professor": "Yuranis Henriquez Nuñez", "nrc": "2236", "groupId": 1, "schedules": [{"day": "Lunes", "time": "07:00 - 07:50"}, {"day": "Viernes", "time": "08:00 - 09:50"}]}]
])

# --- Caso de Prueba Unitario ---

def test_backtracking_correctness_real_data():
    """
    Valida que el algoritmo 'find_valid_schedules' genere el número exacto de
    horarios válidos para el "Golden Dataset" definido.
    """
    # Se combinan las opciones de las 3 materias en la estructura de entrada
    # que espera el algoritmo: una lista de listas de opciones de clase.
    all_combinations = [fisica_options, foto_options, poo_options]
    
    # El número esperado de horarios válidos (7) fue determinado mediante análisis manual
    # de los conflictos y combinaciones posibles del dataset.
    EXPECTED_COUNT = 7

    # Se ejecuta el algoritmo con el conjunto de datos de prueba.
    schedules = find_valid_schedules(all_combinations, {})

    # La aserción (assert) comprueba si el número de horarios generados coincide
    # con el resultado esperado. Si no coincide, la prueba falla.
    assert len(schedules) == EXPECTED_COUNT, \
        f"Se esperaban {EXPECTED_COUNT} horarios, pero se generaron {len(schedules)}"

