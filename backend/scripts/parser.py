from collections import defaultdict
from utils import limpiar_nombre, formatear_hora, obtener_dias

def procesar_json(data):
    materias = {}
    profesores = {}
    cursos = []
    clases = []
    errores = []

    group_counter = defaultdict(lambda: defaultdict(int))
    grupo_teoricos = defaultdict(dict)

    # Primera pasada: identificar todos los cursos teóricos
    for entrada in data['data']:
        subject_course = entrada['subjectCourse']
        link_id = entrada.get('linkIdentifier')
        is_linked = entrada.get('isSectionLinked', False)
        tipo = entrada['scheduleTypeDescription'].strip().upper()
        if tipo == "TEORICO":
            key = link_id[1] if is_linked and len(link_id) > 1 else link_id
            grupo_teoricos[subject_course][key] = int(entrada['courseReferenceNumber'])

    # Segunda pasada: procesar materias, profesores, cursos y clases
    for entrada in data['data']:
        subject_course = entrada['subjectCourse']
        link_id = entrada.get('linkIdentifier')
        is_linked = entrada.get('isSectionLinked', False)
        tipo = entrada['scheduleTypeDescription'].strip().upper()
        tipo_formateado = 'Teórico' if tipo == 'TEORICO' else 'Laboratorio'
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
        key = link_id[1] if is_linked and len(link_id) > 1 else link_id
        if key not in group_counter[subject_course]:
            group_counter[subject_course][key] = len(group_counter[subject_course]) + 1
        group_id = group_counter[subject_course][key]

        # Verificación de cursos ligados
        if tipo_formateado == "Laboratorio" and is_linked:
            nrc_teorico = grupo_teoricos[subject_course].get(key)
            if not nrc_teorico:
                errores.append(f"Curso ligado sin teórico: NRC {nrc} - {subject_course} - {link_id}")
                continue  # No se agrega a la base de datos
        else:
            nrc_teorico = None

        # Curso
        cursos.append((nrc, tipo_formateado, subject_course, profesor_id, nrc_teorico, group_id))

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
