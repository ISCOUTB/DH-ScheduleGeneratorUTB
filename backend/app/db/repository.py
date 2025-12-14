"""
Módulo de repositorio para interactuar con la base de datos PostgreSQL.
Gestiona las consultas para obtener información sobre materias, cursos y horarios.
"""
import psycopg
import psycopg.rows
import os
from dotenv import load_dotenv
from typing import List, Dict, Any
from psycopg.sql import SQL
from ..models import ClassOption, Schedule, Subject

# Define la ruta base del proyecto (la carpeta 'backend')
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Carga el .env.local para desarrollo si existe
load_dotenv(dotenv_path=os.path.join(BASE_DIR, '.env.local'))

# Si DATABASE_URL no se cargó, carga el .env principal (para Docker)
if not os.getenv('DATABASE_URL'):
    load_dotenv(dotenv_path=os.path.join(BASE_DIR, '.env'))

# Lee la URL de conexión completa directamente desde el entorno.
DATABASE_URL = os.getenv('DATABASE_URL')

def get_db_connection():
    """Crea y devuelve una nueva conexión a la base de datos."""
    if not DATABASE_URL:
        raise ValueError("DATABASE_URL no está definida. Asegúrate de que backend/.env o backend/.env.local exista y esté configurado.")
    
    return psycopg.connect(DATABASE_URL)


def _get_option_combinations(class_options: List[ClassOption]) -> List[List[ClassOption]]:
    """
    Agrupa las opciones de clase por grupo y nombre de materia, y genera combinaciones válidas.
    Una combinación puede ser una clase 'Teorico-practico' o un par 'Teórico' y 'Laboratorio'.
    """

    # Se agrupa por una tupla de (group_id, subject_name) para diferenciar
    # materias con el mismo código pero diferente nombre (ej. las Éticas).
    options_by_group: Dict[tuple[int, str], List[ClassOption]] = {}

    for option in class_options:
        # Usamos una clave compuesta para la agrupación.
        group_key = (option.group_id, option.subject_name)
        options_by_group.setdefault(group_key, []).append(option)


    combinations: List[List[ClassOption]] = []

    for group_options in options_by_group.values():
        teoricas = [opt for opt in group_options if opt.type == 'Teórico']
        labs = [opt for opt in group_options if opt.type == 'Laboratorio']
        teorico_practicas = [opt for opt in group_options if opt.type == 'Teorico-practico']

        combinations.extend([[tp] for tp in teorico_practicas])

        if teoricas and labs:
            combinations.extend([[t, l] for t in teoricas for l in labs])
        elif teoricas:
            combinations.extend([[t] for t in teoricas])
        elif labs:
            combinations.extend([[l] for l in labs])

    return combinations


def get_combinations_for_subjects(subjects_payload: List[Dict[str, str]]) -> List[List[List[ClassOption]]]:
    """
    Obtiene todas las combinaciones de clases posibles para una lista de materias,
    filtrando por código y nombre de curso específico.
    """
    if not subjects_payload:
        return []

    conn = get_db_connection()
    cursor = conn.cursor()


    conditions: List[SQL] = []
    params: List[Any] = []
    for subject in subjects_payload:
        conditions.append(SQL("(c.CodigoMateria = %s AND c.nombremateria = %s)"))
        params.extend([subject['code'], subject['name']])

    where_clause = SQL(" OR ").join(conditions)

    query = SQL("""
        SELECT
            c.CodigoMateria, c.nombremateria AS NombreCurso, m.Creditos,
            c.NRC, c.Tipo, c.GroupID, p.Nombre AS NombreProfesor,
            cl.Dia, cl.HoraInicio, cl.HoraFinal, c.Campus, c.CuposDisponibles, c.CuposTotales
        FROM Curso c
        JOIN Materia m ON c.CodigoMateria = m.CodigoMateria AND m.Nombre = c.nombremateria
        LEFT JOIN Profesor p ON c.ProfesorID = p.BannerID
        LEFT JOIN Clase cl ON cl.NRC = c.NRC
        WHERE {where_clause}
        ORDER BY
            c.CodigoMateria,
            c.nombremateria,
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
    """).format(where_clause=where_clause)
    
    cursor.execute(query, params)


    rows = cursor.fetchall()
    cursor.close()
    conn.close()

    all_options_by_subject: Dict[tuple[str, str], List[ClassOption]] = {}
    class_options_dict: Dict[str, ClassOption] = {}

    for row in rows:
        (
            code, name, credits, nrc_val, tipo, group_id,
            profesor, dia, hora_inicio, hora_final, campus, cupos_disponibles, cupos_totales
        ) = row

        nrc = str(nrc_val)
        subject_key = (code, name)

        if subject_key not in all_options_by_subject:
            all_options_by_subject[subject_key] = []

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
                campus=campus,
                seatsAvailable=cupos_disponibles,
                seatsMaximum=cupos_totales
            )
            class_options_dict[nrc] = new_option
            all_options_by_subject[subject_key].append(new_option)

        if dia and hora_inicio and hora_final:
            hora_inicio_str = hora_inicio.strftime("%H:%M")
            hora_final_str = hora_final.strftime("%H:%M")
            class_options_dict[nrc].schedules.append(
                Schedule(day=dia, time=f"{hora_inicio_str} - {hora_final_str}")
            )

    combinations_per_subject: List[List[List[ClassOption]]] = []
    for subject_key in all_options_by_subject:
        subject_options = all_options_by_subject.get(subject_key, [])
        if subject_options:
            combinations = _get_option_combinations(subject_options)
            if combinations:
                combinations_per_subject.append(combinations)

    return combinations_per_subject


def get_subject_by_code(subject_code: str, subject_name: str) -> Subject | None:
    """
    Obtiene los detalles completos de una materia específica desde la base de datos,
    incluyendo todas sus opciones de clase (classOptions).
    """
    conn = get_db_connection()
    cursor = conn.cursor()


    # Se aplica la misma lógica de JOIN y WHERE a esta consulta.
    query = """
        SELECT
            c.CodigoMateria, c.nombremateria AS NombreMateria, m.Creditos,
            c.NRC, c.Tipo, c.GroupID, p.Nombre AS NombreProfesor,
            cl.Dia, cl.HoraInicio, cl.HoraFinal, c.campus, c.CuposDisponibles, c.CuposTotales
        FROM Curso c
        JOIN Materia m ON c.CodigoMateria = m.CodigoMateria AND m.Nombre = c.nombremateria
        LEFT JOIN Profesor p ON c.ProfesorID = p.BannerID
        LEFT JOIN Clase cl ON cl.NRC = c.NRC
        WHERE c.CodigoMateria = %s AND c.nombremateria = %s
        ORDER BY
            c.CodigoMateria,
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

    cursor.execute(query, (subject_code, subject_name))
    
    rows = cursor.fetchall()
    cursor.close()
    conn.close()

    if not rows:
        return None

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
            profesor, dia, hora_inicio, hora_final, campus, cupos_disponibles, cupos_totales
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
                campus=campus,
                seatsAvailable=cupos_disponibles,
                seatsMaximum=cupos_totales
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
    conn = get_db_connection()
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)

    cursor.execute("SELECT CodigoMateria as code, Nombre as name, Creditos as credits FROM Materia ORDER BY Nombre;")

    subjects = cursor.fetchall()

    cursor.close()
    conn.close()

    return [dict(s) for s in subjects]


# --- Funciones de Usuario ---

def get_or_create_user(entra_id: str, email: str, nombre: str = None) -> Dict[str, Any]:
    """
    Obtiene un usuario existente o lo crea si no existe.
    Retorna un diccionario con la información del usuario.
    """
    conn = get_db_connection()
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)
    
    try:
        # Intentar obtener el usuario existente
        cursor.execute(
            "SELECT id, email, nombre, entra_id, created_at FROM usuario WHERE entra_id = %s",
            (entra_id,)
        )
        user = cursor.fetchone()
        
        if user:
            # Actualizar nombre si cambió
            if nombre and user.get("nombre") != nombre:
                cursor.execute(
                    "UPDATE usuario SET nombre = %s WHERE entra_id = %s",
                    (nombre, entra_id)
                )
                conn.commit()
                user = dict(user)
                user["nombre"] = nombre
            return dict(user)
        
        # Crear nuevo usuario
        cursor.execute(
            """
            INSERT INTO usuario (entra_id, email, nombre)
            VALUES (%s, %s, %s)
            RETURNING id, email, nombre, entra_id, created_at
            """,
            (entra_id, email, nombre)
        )
        new_user = cursor.fetchone()
        conn.commit()
        
        return dict(new_user)
        
    finally:
        cursor.close()
        conn.close()


def get_user_by_id(user_id: int) -> Dict[str, Any] | None:
    """
    Obtiene un usuario por su ID.
    """
    conn = get_db_connection()
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)
    
    try:
        cursor.execute(
            "SELECT id, email, nombre, entra_id, created_at FROM usuario WHERE id = %s",
            (user_id,)
        )
        user = cursor.fetchone()
        return dict(user) if user else None
        
    finally:
        cursor.close()
        conn.close()