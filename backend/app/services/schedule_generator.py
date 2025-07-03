from typing import List, Dict, Tuple, Any, cast
from datetime import time
from ..models import ClassOption, Schedule

# --- Funciones de Ayuda para Manejar Tiempos ---

def _parse_time(time_str: str) -> time:
    parts = time_str.split(':')
    return time(hour=int(parts[0]), minute=int(parts[1]))

def _parse_time_range(time_range_str: str) -> Tuple[time, time]:
    start_str, end_str = time_range_str.split(' - ')
    return _parse_time(start_str.strip()), _parse_time(end_str.strip())

def _schedules_overlap(schedule1: Schedule, schedule2: Schedule) -> bool:
    if schedule1.day != schedule2.day:
        return False
    
    start1, end1 = _parse_time_range(schedule1.time)
    start2, end2 = _parse_time_range(schedule2.time)

    return start1 < end2 and end1 > start2

# --- Función para crear la "Huella Digital" de un Horario ---

def _get_schedule_signature(schedule: List[ClassOption]) -> str:
    """
    Crea una 'huella digital' única para un horario basada en la combinación
    de materia, profesor y bloques de tiempo. Esto permite identificar horarios
    que son funcionalmente idénticos para el usuario.
    """
    # SOLUCIÓN: Especificar explícitamente que el conjunto contendrá strings (str).
    time_slots: set[str] = set()
    for option in schedule:
        signature_part = f"{option.subject_code}:{option.professor}"
        for s in option.schedules:
            signature_part += f"@{s.day}:{s.time.replace(' ', '')}"
        time_slots.add(signature_part)
    
    return ";".join(sorted(list(time_slots)))

# --- Lógica Principal del Algoritmo ---

def find_valid_schedules(
    combinations_per_subject: List[List[List[ClassOption]]], 
    filters: Dict[str, Any]
) -> List[List[ClassOption]]:
    
    valid_schedules: List[List[ClassOption]] = []
    # SOLUCIÓN: Cambiar el valor por defecto de max_credits a 20.
    # Si el frontend no envía un valor para 'max_credits', se usará 20.
    # Si el frontend envía 'max_credits: 18', ese valor anulará el de por defecto.
    max_credits = filters.get("max_credits", 20)

    # SOLUCIÓN: Modificar la firma de _backtrack para que lleve la cuenta de los créditos.
    def _backtrack(level: int, current_schedule: List[ClassOption], current_credits: int):
        # Condición de éxito: si hemos procesado todas las materias.
        if level == len(combinations_per_subject):
            # Los filtros de profesor/hora se aplican al final sobre los horarios ya válidos.
            if _meets_filters(current_schedule, filters):
                valid_schedules.append(list(current_schedule))
            return

        # Iterar sobre cada grupo de opciones para la materia actual.
        for option_group in combinations_per_subject[level]:
            
            # SOLUCIÓN: Lógica de poda por créditos.
            # Los componentes de un grupo tienen los mismos créditos.
            credits_for_this_group = option_group[0].credits
            if current_credits + credits_for_this_group > max_credits:
                # Si añadir esta materia excede el límite, se ignora esta opción
                # y se pasa a la siguiente (poda).
                continue

            if not _has_conflict(current_schedule, option_group):
                current_schedule.extend(option_group)
                # SOLUCIÓN: Llamar a la recursión con los créditos actualizados.
                _backtrack(level + 1, current_schedule, current_credits + credits_for_this_group)
                # Backtrack: eliminar las clases añadidas para probar la siguiente opción.
                for _ in range(len(option_group)):
                    current_schedule.pop()

    # SOLUCIÓN: Iniciar el backtracking con 0 créditos acumulados.
    _backtrack(0, [], 0)
    
    # --- PASO DE FUSIÓN DE HORARIOS ---
    # Agrupa horarios por su "huella digital" para fusionar sus NRCs.
    grouped_schedules: Dict[str, List[List[ClassOption]]] = {}
    for schedule in valid_schedules:
        signature = _get_schedule_signature(schedule)
        grouped_schedules.setdefault(signature, []).append(schedule)
        
    # Fusiona los grupos en un único horario consolidado.
    merged_schedules: List[List[ClassOption]] = []
    for group in grouped_schedules.values():
        if not group:
            continue
        
        base_schedule = group[0]
        
        if len(group) > 1:
            base_nrcs = {opt.nrc for opt in base_schedule}
            for other_schedule in group[1:]:
                for option in other_schedule:
                    if option.nrc not in base_nrcs:
                        base_schedule.append(option)
                        base_nrcs.add(option.nrc)
                        
        merged_schedules.append(base_schedule)
            
    # --- PASO DE OPTIMIZACIÓN Y ORDENAMIENTO ---
    # Aplica los filtros de optimización si están activados.
    if filters.get('optimizeGaps', False) or filters.get('optimizeFreeDays', False):
        merged_schedules.sort(
            key=lambda s: _calculate_schedule_score(s, filters),
            reverse=True  # Mayor puntuación es mejor
        )

    return merged_schedules


def _has_conflict(current_schedule: List[ClassOption], new_option_group: List[ClassOption]) -> bool:
    for existing_option in current_schedule:
        for new_option in new_option_group:
            # Ignora conflictos entre clases del mismo grupo (ej. labs alternos)
            if (existing_option.subject_code == new_option.subject_code and
                existing_option.group_id == new_option.group_id):
                continue

            for s1 in existing_option.schedules:
                for s2 in new_option.schedules:
                    if _schedules_overlap(s1, s2):
                        return True
    return False


def _calculate_schedule_score(schedule: List[ClassOption], filters: Dict[str, Any]) -> Tuple[float, float]:
    """
    Calcula una puntuación para un horario. Mayor puntuación es mejor.
    La puntuación es una tupla para ordenar por múltiples criterios.
    """
    score_free_days = 0.0
    score_gaps = 0.0

    # --- 1. Puntuación por Días Libres ---
    if filters.get('optimizeFreeDays', False):
        days_with_classes = {s.day.lower() for opt in schedule for s in opt.schedules}
        # Más días libres = mayor puntuación. 7 días total - días con clase.
        score_free_days = 7 - len(days_with_classes)

    # --- 2. Puntuación por Huecos (Gaps) ---
    if filters.get('optimizeGaps', False):
        total_gap_hours = 0
        schedule_by_day: Dict[str, List[Tuple[time, time]]] = {}
        
        for option in schedule:
            for s in option.schedules:
                day = s.day.lower()
                time_range = _parse_time_range(s.time)
                schedule_by_day.setdefault(day, []).append(time_range)
        
        for day, times in schedule_by_day.items():
            if len(times) > 1:
                # Ordenar clases por hora de inicio
                sorted_times = sorted(times, key=lambda x: x[0])
                for i in range(len(sorted_times) - 1):
                    end_of_class1 = sorted_times[i][1]
                    start_of_class2 = sorted_times[i+1][0]
                    
                    # Calcular la diferencia en minutos
                    gap_minutes = (start_of_class2.hour * 60 + start_of_class2.minute) - \
                                  (end_of_class1.hour * 60 + end_of_class1.minute)
                    
                    if gap_minutes > 0:
                        total_gap_hours += gap_minutes / 60
        
        # Puntuación inversa: menos huecos = mayor puntuación.
        # Se usa un número grande para restar, así un total_gap_hours más pequeño da un resultado mayor.
        score_gaps = 100 - total_gap_hours

    # Se prioriza días libres, luego huecos.
    return (score_free_days, score_gaps)


def _meets_filters(schedule: List[ClassOption], filters: Dict[str, Any]) -> bool:
    """
    Verifica si un horario cumple con todos los filtros aplicados por el usuario,
    de forma insensible a mayúsculas/minúsculas.
    NOTA: El filtro de max_credits ya no se maneja aquí, sino en el backtracking.
    """
    # --- 1. Extraer y normalizar filtros ---
    exclude_professors_filter = cast(Dict[str, List[str]], filters.get('exclude_professors', {}))
    include_professors_filter = cast(Dict[str, List[str]], filters.get('include_professors', {}))
    
    # Normalizamos las claves del filtro de horas (días) a minúsculas
    unavailable_slots_input = cast(Dict[str, List[str]], filters.get('unavailable_slots', {}))
    unavailable_slots_lower = {day.lower(): times for day, times in unavailable_slots_input.items()}

    # --- 2. Agrupar clases por materia para una validación eficiente ---
    schedule_by_subject: Dict[str, List[ClassOption]] = {}
    for option in schedule:
        schedule_by_subject.setdefault(option.subject_code, []).append(option)

    # --- 3. Verificación de filtros por materia (Inclusión/Exclusión de Profesores) ---
    for subject_code, subject_options in schedule_by_subject.items():
        # Verificación de EXCLUSIÓN (Case-Insensitive)
        if subject_code in exclude_professors_filter:
            excluded_profs_set = {prof.lower() for prof in exclude_professors_filter[subject_code]}
            for option in subject_options:
                if option.professor.lower() in excluded_profs_set:
                    return False # Filtro de exclusión fallido

        # Verificación de INCLUSIÓN (Case-Insensitive)
        if subject_code in include_professors_filter:
            included_profs_set = {prof.lower() for prof in include_professors_filter[subject_code]}
            professors_in_schedule = {opt.professor.lower() for opt in subject_options}
            if not professors_in_schedule.intersection(included_profs_set):
                return False # Filtro de inclusión fallido

    # --- 4. Verificación de HORAS NO DISPONIBLES (Case-Insensitive para los días) ---
    for option in schedule:
        for class_time in option.schedules:
            day_lower = class_time.day.lower()
            if day_lower in unavailable_slots_lower:
                class_start, class_end = _parse_time_range(class_time.time)
                for unavailable_hour_str in unavailable_slots_lower[day_lower]:
                    unavailable_time = _parse_time(unavailable_hour_str)
                    if class_start <= unavailable_time < class_end:
                        return False # Se solapa con una hora no disponible
                        
    return True