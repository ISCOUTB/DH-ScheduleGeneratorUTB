"""
Módulo de repositorio para interactuar con la base de datos PostgreSQL.
Gestiona las consultas para obtener información sobre materias, cursos y horarios.
"""
import psycopg
import psycopg.rows
import os
from dotenv import load_dotenv
from typing import List, Dict, Any
from ..models import ClassOption, Schedule, Subject

# Carga las variables de entorno para la configuración de la base de datos.
load_dotenv()

# --- Configuración de la Base de Datos desde Variables de Entorno ---
# Obtiene las credenciales de la base de datos desde el archivo .env.
db_name = os.getenv("DB_NAME")
db_user = os.getenv("DB_USER")
db_password = os.getenv("DB_PASSWORD")
db_host = os.getenv("DB_HOST")
db_port = os.getenv("DB_PORT")

# Verifica que todas las variables de entorno necesarias estén definidas.
if not all([db_name, db_user, db_password, db_host, db_port]):
    raise ValueError("Una o más variables de entorno de la base de datos no están definidas. Revisa tu archivo .env")


def _get_option_combinations(class_options: List[ClassOption]) -> List[List[ClassOption]]:
    """
    Agrupa las opciones de clase por grupo y genera combinaciones válidas.
    Una combinación puede ser una clase 'Teorico-practico' o un par 'Teórico' y 'Laboratorio'.
    """
    options_by_group: Dict[int, List[ClassOption]] = {}

    # Se convierte la lista a un diccionario agrupado por group_id. 
    for option in class_options:
        options_by_group.setdefault(option.group_id, []).append(option)
        
    combinations: List[List[ClassOption]] = []

    for group_options in options_by_group.values():
        teoricas = [opt for opt in group_options if opt.type == 'Teórico']
        labs = [opt for opt in group_options if opt.type == 'Laboratorio']
        teorico_practicas = [opt for opt in group_options if opt.type == 'Teorico-practico']

        # Combinaciones de clases 'Teorico-practico' (cada una es una combinación en sí misma)
        combinations.extend([[tp] for tp in teorico_practicas])
        
        # Combinaciones de 'Teórico' + 'Laboratorio'
        if teoricas and labs:
            combinations.extend([[t, l] for t in teoricas for l in labs])
        # Combinaciones de 'Teórico' solo
        elif teoricas:
            combinations.extend([[t] for t in teoricas])
        # Combinaciones de 'Laboratorio' solo
        elif labs:
            combinations.extend([[l] for l in labs])

    return combinations


def get_combinations_for_subjects(subject_codes: List[str]) -> List[List[List[ClassOption]]]:
    """
    Obtiene todas las combinaciones de clases posibles para una lista de códigos de materia.
    """
    if not subject_codes:
        return []

    # Establece la conexión con la base de datos.
    conn = psycopg.connect(
        dbname=db_name,
        user=db_user,
        password=db_password,
        host=db_host,
        port=db_port
    )
    cursor = conn.cursor()

    # Consulta SQL para obtener todos los datos de materias, cursos, profesores y clases.
    query = """
        SELECT 
            m.CodigoMateria, m.Nombre AS NombreMateria, m.Creditos,
            c.NRC, c.Tipo, c.GroupID, p.Nombre AS NombreProfesor,
            cl.Dia, cl.HoraInicio, cl.HoraFinal, c.Campus
        FROM Materia m
        JOIN Curso c ON m.CodigoMateria = c.CodigoMateria
        LEFT JOIN Profesor p ON c.ProfesorID = p.BannerID
        LEFT JOIN Clase cl ON cl.NRC = c.NRC
        WHERE m.CodigoMateria = ANY(%s)
        ORDER BY 
            m.CodigoMateria,
            c.GroupID,
            c.NRC,
            CASE cl.Dia
                WHEN 'Lunes' THEN 1
                WHEN 'Martes' THEN 2
                WHEN 'Miércoles' THEN 3
                WHEN 'Jueves' THEN 4
                WHEN 'Viernes' THEN 5
                WHEN 'Sábado' THEN 6
                WHEN 'Domingo' THEN 7
                ELSE 8
            END,
            cl.HoraInicio;
    """
    
    # Ejecuta la consulta de forma segura.
    cursor.execute(query, (subject_codes,))
    rows = cursor.fetchall()
    cursor.close()
    conn.close()

    # Procesa los resultados para construir los objetos ClassOption.
    all_options_by_subject: Dict[str, List[ClassOption]] = {}
    class_options_dict: Dict[str, ClassOption] = {}

    for row in rows:
        (
            code, name, credits, nrc_val, tipo, group_id,
            profesor, dia, hora_inicio, hora_final, campus
        ) = row
        
        nrc = str(nrc_val)

        if code not in all_options_by_subject:
            all_options_by_subject[code] = []

        if nrc not in class_options_dict:
            new_option = ClassOption(
                subjectName=name,
                subjectCode=code,
                type=tipo,
                schedules=[],
                professor=profesor or "Por Asignar",
                nrc=nrc,
                groupId=group_id,
                credits=credits,
                campus=campus
            )
            class_options_dict[nrc] = new_option
            all_options_by_subject[code].append(new_option)

        if dia and hora_inicio and hora_final:
            hora_inicio_str = hora_inicio.strftime("%H:%M")
            hora_final_str = hora_final.strftime("%H:%M")
            class_options_dict[nrc].schedules.append(
                Schedule(day=dia, time=f"{hora_inicio_str} - {hora_final_str}")
            )

    # Genera las combinaciones de clases para cada materia.
    combinations_per_subject: List[List[List[ClassOption]]] = []
    for code in subject_codes:
        subject_options = all_options_by_subject.get(code, [])
        if subject_options:
            combinations = _get_option_combinations(subject_options)
            if combinations:
                combinations_per_subject.append(combinations)
            
    return combinations_per_subject


def get_subject_by_code(subject_code: str) -> Subject | None:
    """
    Obtiene los detalles completos de una materia específica desde la base de datos,
    incluyendo todas sus opciones de clase (classOptions).
    """
    conn = psycopg.connect(
        dbname=db_name, user=db_user, password=db_password, host=db_host, port=db_port
    )
    cursor = conn.cursor()

    # Consulta SQL para obtener los detalles de la materia y sus opciones de clase.
    query = """
        SELECT 
            m.CodigoMateria, m.Nombre AS NombreMateria, m.Creditos,
            c.NRC, c.Tipo, c.GroupID, p.Nombre AS NombreProfesor,
            cl.Dia, cl.HoraInicio, cl.HoraFinal, c.campus
        FROM Materia m
        JOIN Curso c ON m.CodigoMateria = c.CodigoMateria
        LEFT JOIN Profesor p ON c.ProfesorID = p.BannerID
        LEFT JOIN Clase cl ON cl.NRC = c.NRC
        WHERE m.CodigoMateria = %s
        ORDER BY 
            m.CodigoMateria,
            c.GroupID,
            c.NRC,
            CASE cl.Dia
                WHEN 'Lunes' THEN 1
                WHEN 'Martes' THEN 2
                WHEN 'Miércoles' THEN 3
                WHEN 'Jueves' THEN 4
                WHEN 'Viernes' THEN 5
                WHEN 'Sábado' THEN 6
                WHEN 'Domingo' THEN 7
                ELSE 8
            END,
            cl.HoraInicio;
    """
    
    cursor.execute(query, (subject_code,))
    rows = cursor.fetchall()
    cursor.close()
    conn.close()

    if not rows:
        return None

    # Procesa las filas para construir el objeto Subject con sus ClassOption.
    subject_details: Dict[str, Any] = {}
    subject_details = {
        "code": rows[0][0],
        "name": rows[0][1],
        "credits": rows[0][2],
        "classOptions": []
    }
    class_options_dict: Dict[str, ClassOption] = {}

    for row in rows:
        (
            code, name, credits, nrc_val, tipo, group_id,
            profesor, dia, hora_inicio, hora_final, campus
        ) = row
        
        nrc = str(nrc_val)

        if nrc not in class_options_dict:
            new_option = ClassOption(
                subjectName=name,
                subjectCode=code,
                type=tipo,
                schedules=[],
                professor=profesor or "Por Asignar",
                nrc=nrc,
                groupId=group_id,
                credits=credits,
                campus=campus
            )
            class_options_dict[nrc] = new_option

        if dia and hora_inicio and hora_final:
            hora_inicio_str = hora_inicio.strftime("%H:%M")
            hora_final_str = hora_final.strftime("%H:%M")
            class_options_dict[nrc].schedules.append(
                Schedule(day=dia, time=f"{hora_inicio_str} - {hora_final_str}")
            )
    
    subject_details["classOptions"] = list(class_options_dict.values())
    
    return Subject(**subject_details)


def get_all_subjects_summary() -> List[Dict[str, Any]]:
    """
    Obtiene una lista de resúmenes de todas las materias (código, nombre, créditos).
    """
    # Conecta a la base de datos.
    conn = psycopg.connect(
        dbname=db_name,
        user=db_user,
        password=db_password,
        host=db_host,
        port=db_port
    )
    # Usa dict_row para que la BD devuelva diccionarios directamente.
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)
    
    cursor.execute("SELECT CodigoMateria as code, Nombre as name, Creditos as credits FROM Materia ORDER BY Nombre;")
    
    subjects = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    # Convierte el resultado a una lista de diccionarios estándar.
    return [dict(s) for s in subjects]