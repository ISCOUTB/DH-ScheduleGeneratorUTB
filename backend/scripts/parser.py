from collections import defaultdict
from utils import limpiar_nombre, formatear_hora, obtener_dias
from typing import Any, Optional, TypedDict

class ProcesarJsonResponse(TypedDict):
    materias: list[tuple[str, int, str]]
    profesores: list[tuple[str, str]]
    cursos: list[tuple[int, str, str, Optional[str], Optional[int], int, str, int, int]]
    clases: list[tuple[int, Optional[str], Optional[str], Optional[str], str]]
    errores: list[str]

def procesar_json(data: dict[str, list[dict[str, Any]]]) -> ProcesarJsonResponse:

    materias: dict[str, tuple[str, int, str]] = {}
    profesores: dict[str, tuple[str, str]] = {}
    cursos: list[tuple[int, str, str, Optional[str], Optional[int], int, str, int, int]] = []
    clases: list[tuple[int, Optional[str], Optional[str], Optional[str], str]] = []
    errores: list[str] = []

    group_counter: defaultdict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    
    # Mapa de teóricos: { subject_course: { sequence_number: nrc } }
    mapa_teoricos: defaultdict[str, dict[str, int]] = defaultdict(dict)
    teoricos_con_hijos: set[int] = set()

    # Primera pasada: Identificar todos los teóricos por su sequenceNumber
    for entrada in data['data']:
        tipo = entrada['scheduleTypeDescription'].strip().upper()
        if tipo == "TEORICO":
            subject_course = entrada['subjectCourse']
            sequence_number = entrada['sequenceNumber']
            nrc = int(entrada['courseReferenceNumber'])
            mapa_teoricos[subject_course][sequence_number] = nrc

    # Segunda pasada: Procesar y agrupar todo
    for entrada in data['data']:
        subject_course = entrada['subjectCourse']
        tipo = entrada['scheduleTypeDescription'].strip().upper()
        tipo_formateado = 'Teórico' if tipo == 'TEORICO' else 'Laboratorio'
        sequence_number = entrada['sequenceNumber']
        nrc = int(entrada['courseReferenceNumber'])
        
        # Determina de enlace. Debido al origen de los datos, se confía más en la existencia de
        # linkIdentifier que en la bandera isSectionLinked.
        link_id = entrada.get('linkIdentifier')
        is_linked = link_id is not None

        # --- Lógica de Agrupamiento ---
        group_key: str = ""
        nrc_teorico: Optional[int] = None

        if tipo_formateado == 'Teórico':
            # Los teóricos siempre definen su propio grupo.
            group_key = f"{subject_course}-{nrc}"

        elif is_linked: # Es un Laboratorio que debería estar ligado.
            # Busca el teórico correspondiente basándose en el prefijo del sequenceNumber.
            teorico_encontrado = False
            teoricos_de_materia = sorted(mapa_teoricos[subject_course].keys(), key=len, reverse=True)
            
            for seq_teorico in teoricos_de_materia:
                if sequence_number.startswith(seq_teorico):
                    nrc_teorico = mapa_teoricos[subject_course][seq_teorico]
                    teoricos_con_hijos.add(nrc_teorico) # <--- AÑADIR ESTA LÍNEA
                    group_key = f"{subject_course}-{nrc_teorico}" # Se une al grupo de su teórico.
                    teorico_encontrado = True
                    break
            
            if not teorico_encontrado:
                # Si no se encuentra un teórico, se registra un error.
                errores.append(f"Laboratorio ligado sin teórico: NRC {nrc} - {subject_course} (Seq: {sequence_number})")
                continue # Descartamos este curso por completo.

        else: # Es un Laboratorio no ligado (ej. Práctica Profesional)
            # Es un curso válido e independiente.
            group_key = f"{subject_course}-{nrc}"

        # Asignar GroupID
        if group_key not in group_counter[subject_course]:
            group_counter[subject_course][group_key] = len(group_counter[subject_course]) + 1
        group_id = group_counter[subject_course][group_key]
        # --- Fin de la Lógica de Agrupamiento ---

        # Procesar información del curso
        campus = entrada['campusDescription']
        seats_a = entrada.get('seatsAvailable', 0)
        seats_m = entrada.get('maximumEnrollment', 0)

        if subject_course not in materias:
            creditos = entrada.get('creditHourHigh') or entrada.get('creditHourLow', 0)
            nombre_materia = limpiar_nombre(entrada['courseTitle'])
            materias[subject_course] = (subject_course, creditos, nombre_materia)

        profesor_id = None
        if entrada.get('faculty'):
            profesor_info = entrada['faculty'][0]
            profesor_id = profesor_info['bannerId']
            if profesor_id not in profesores:
                nombre_profesor = limpiar_nombre(profesor_info['displayName'])
                profesores[profesor_id] = (profesor_id, nombre_profesor)

        campus = limpiar_nombre(campus) if campus else "Sin información"

        cursos.append((nrc, tipo_formateado, subject_course, profesor_id, nrc_teorico, group_id, campus, seats_a, seats_m))

        for mf in entrada.get('meetingsFaculty', []):
            mt = mf.get('meetingTime', {})
            if not mt.get('beginTime') or not mt.get('endTime'):
                continue
            dias = obtener_dias(mt)
            aula = mt.get('room') or None
            for dia in dias:
                clases.append((nrc, formatear_hora(mt['beginTime']), formatear_hora(mt['endTime']), aula, dia))

    # Tercera pasada: Verifica teóricos que deberían tener labs y no tienen
    for entrada in data['data']:
        tipo = entrada['scheduleTypeDescription'].strip().upper()
        link_id = entrada.get('linkIdentifier')
        nrc = int(entrada['courseReferenceNumber'])

        # Caso en el que un curso es un teórico CON linkIdentifier pero nunca fue reclamado por un curso teórico
        if tipo == "TEORICO" and link_id and nrc not in teoricos_con_hijos:
            subject_course = entrada['subjectCourse']
            sequence_number = entrada['sequenceNumber']
            errores.append(f"Teórico ligado sin laboratorios: NRC {nrc} - {subject_course} (Seq: {sequence_number})")

    return {
        'materias': list(materias.values()),
        'profesores': list(profesores.values()),
        'cursos': cursos,
        'clases': clases,
        'errores': errores
    }