from collections import defaultdict
from utils import limpiar_nombre, formatear_hora, obtener_dias
from typing import Any, Optional, TypedDict

class ProcesarJsonResponse(TypedDict):
    materias: list[tuple[str, int, str]]
    profesores: list[tuple[str, str]]
    cursos: list[tuple[int, str, str, Optional[str], Optional[int], int, str]]
    clases: list[tuple[int, Optional[str], Optional[str], Optional[str], str]]
    errores: list[str]

def procesar_json(data: dict[str, list[dict[str, Any]]]) -> ProcesarJsonResponse:

    materias: dict[str, tuple[str, int, str]] = {}  # subjectCourse: (subjectCourse, creditos, nombre_materia)
    profesores: dict[str, tuple[str, str]] = {}  # Estructura: profesor_id: (profesor_id, nombre_profesor)
    cursos: list[tuple[int, str, str, Optional[str], Optional[int], int, str]] = []  # Estructura: (nrc, tipo, subjectCourse, profesor_id, nrc_teorico, group_id, campus)
    clases: list[tuple[int, Optional[str], Optional[str], Optional[str], str]] = []  # Estructura: (nrc, tipo, subjectCourse, profesor_id, nrc_teorico, group_id, campus)
    errores: list[str] = []

    group_counter: defaultdict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    grupo_teoricos: defaultdict[str, dict[str, int]] = defaultdict(dict)

    # Primera pasada: identificar todos los cursos teóricos
    for entrada in data['data']:
        subject_course: str = entrada['subjectCourse']
        link_id = entrada.get('linkIdentifier')
        is_linked = entrada.get('isSectionLinked', False)
        tipo = entrada['scheduleTypeDescription'].strip().upper()
        nrc = int(entrada['courseReferenceNumber'])

        if tipo == "TEORICO":
            group_key: str
            base_id: str

            if is_linked and link_id:
                if link_id.startswith("L") and len(link_id) > 1:
                    base_id = link_id[1]
                else:
                    base_id = link_id
                group_key = f"{subject_course}-LINK-{base_id}"
            else:
                group_key = f"{subject_course}-NRC-{nrc}"

            grupo_teoricos[subject_course][group_key] = int(entrada['courseReferenceNumber'])


    # Segunda pasada: procesar materias, profesores, cursos y clases
    for entrada in data['data']:
        subject_course = entrada['subjectCourse']
        link_id = entrada.get('linkIdentifier')
        is_linked = entrada.get('isSectionLinked', False)
        tipo = entrada['scheduleTypeDescription'].strip().upper()
        tipo_formateado = 'Teórico' if tipo == 'TEORICO' else 'Laboratorio'
        campus = entrada['campusDescription']
        nrc = int(entrada['courseReferenceNumber'])

        # Materia
        if subject_course not in materias:
            creditos = entrada['creditHourHigh'] or entrada['creditHourLow']
            nombre_materia = limpiar_nombre(entrada['courseTitle'])  # Normalizado
            materias[subject_course] = (subject_course, creditos, nombre_materia)

        # Profesor
        profesor_id = None
        if entrada.get('faculty'):
            profesor_info = entrada['faculty'][0]
            profesor_id = profesor_info['bannerId']
            if profesor_id not in profesores:
                nombre_profesor = limpiar_nombre(profesor_info['displayName'])  # Normalizado
                profesores[profesor_id] = (profesor_id, nombre_profesor)

        # GroupID
        if is_linked and link_id:
            # Si el curso está ligado, lo identificamos por su letra base
            if link_id.startswith("L") and len(link_id) > 1:
                base_id = link_id[1]   # "LH" → "H"
            else:
                base_id = link_id      # "H" → "H"
            group_key = f"{subject_course}-LINK-{base_id}"
        else:
            # Si no está ligado, usamos su NRC para asegurarnos de que no se mezcle con otro
            group_key = f"{subject_course}-NRC-{nrc}"
        
        if group_key not in group_counter[subject_course]:
            group_counter[subject_course][group_key] = len(group_counter[subject_course]) + 1

        group_id = group_counter[subject_course][group_key]

        # Verificación de cursos ligados
        if tipo_formateado == "Laboratorio" and is_linked:
            nrc_teorico = grupo_teoricos[subject_course].get(group_key)
            if not nrc_teorico:
                errores.append(f"Curso ligado sin teórico: NRC {nrc} - {subject_course} - {link_id}")
                continue  # No se agrega a la base de datos
        else:
            nrc_teorico = None

        # Campus
        if campus == None:
            campus = "Sin información"
        else:
            campus = limpiar_nombre(campus)

        # Curso
        cursos.append((nrc, tipo_formateado, subject_course, profesor_id, nrc_teorico, group_id, campus))

        # Clases
        for mf in entrada.get('meetingsFaculty', []):
            mt = mf.get('meetingTime', {})
            if not mt.get('beginTime') or not mt.get('endTime'):
                continue
            dias = obtener_dias(mt)
            aula = mt.get('room') if mt.get('room') else None
            for dia in dias:
                clases.append((
                    nrc,
                    formatear_hora(mt['beginTime']),
                    formatear_hora(mt['endTime']),
                    aula,
                    dia
                ))

    return {
        'materias': list(materias.values()),
        'profesores': list(profesores.values()),
        'cursos': cursos,
        'clases': clases,
        'errores': errores
    }
