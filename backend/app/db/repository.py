import psycopg
import psycopg.rows
import os
from dotenv import load_dotenv
from typing import List, Dict, Any
from ..models import ClassOption, Schedule

# Cargar las variables de entorno desde el archivo .env
load_dotenv()

# --- Configuración de la Base de Datos desde Variables de Entorno ---
# Obtenemos las variables y comprobamos que no sean None
db_name = os.getenv("DB_NAME")
db_user = os.getenv("DB_USER")
db_password = os.getenv("DB_PASSWORD")
db_host = os.getenv("DB_HOST")
db_port = os.getenv("DB_PORT")

# Verificación: Si alguna variable esencial no está, el programa no debe continuar.
if not all([db_name, db_user, db_password, db_host, db_port]):
    raise ValueError("Una o más variables de entorno de la base de datos no están definidas. Revisa tu archivo .env")

# Esta función es una traducción directa de `obtenerCombinacionesDeOpciones`
def _get_option_combinations(class_options: List[ClassOption]) -> List[List[ClassOption]]:
    options_by_group: Dict[int, List[ClassOption]] = {}
    for option in class_options:
        options_by_group.setdefault(option.group_id, []).append(option)

    # SOLUCIÓN: Especificar el tipo de la lista al inicializarla
    combinations: List[List[ClassOption]] = []
    # SOLUCIÓN: Usar '_' para la variable no utilizada
    for _, group_options in options_by_group.items():
        teoricas = [opt for opt in group_options if opt.type == 'Teórico']
        labs = [opt for opt in group_options if opt.type == 'Laboratorio']
        teorico_practicas = [opt for opt in group_options if opt.type == 'Teorico-practico']

        if teorico_practicas:
            for tp in teorico_practicas:
                combinations.append([tp])
        
        if teoricas and labs:
            for t in teoricas:
                for l in labs:
                    combinations.append([t, l])
        elif teoricas:
            for t in teoricas:
                combinations.append([t])
        # Ignoramos laboratorios solos, como sucedía en la lógica original

    return combinations

# SOLUCIÓN: Eliminar 'async' ya que psycopg es síncrono
def get_combinations_for_subjects(subject_codes: List[str]) -> List[List[List[ClassOption]]]:
    if not subject_codes:
        return []

    # Conectar a la base de datos de forma explícita
    conn = psycopg.connect(
        dbname=db_name,
        user=db_user,
        password=db_password,
        host=db_host,
        port=db_port
    )
    cursor = conn.cursor()

    # Consulta SQL para obtener todos los datos necesarios de una vez
    query = """
        SELECT 
            m.CodigoMateria, m.Nombre AS NombreMateria, m.Creditos,
            c.NRC, c.Tipo, c.GroupID, p.Nombre AS NombreProfesor,
            cl.Dia, cl.HoraInicio, cl.HoraFinal
        FROM Materia m
        JOIN Curso c ON m.CodigoMateria = c.CodigoMateria
        LEFT JOIN Profesor p ON c.ProfesorID = p.BannerID
        LEFT JOIN Clase cl ON cl.NRC = c.NRC
        WHERE m.CodigoMateria = ANY(%s)
        ORDER BY m.CodigoMateria, c.GroupID, c.NRC, cl.Dia, cl.HoraInicio;
    """
    
    # Ejecutar la consulta de forma segura para prevenir inyecciones SQL
    cursor.execute(query, (subject_codes,))
    rows = cursor.fetchall()
    cursor.close()
    conn.close()

    # Procesar las filas de la BD para construir los objetos Pydantic
    all_options_by_subject: Dict[str, List[ClassOption]] = {}
    class_options_dict: Dict[str, ClassOption] = {}

    for row in rows:
        (
            code, name, credits, nrc_val, tipo, group_id,
            profesor, dia, hora_inicio, hora_final
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
                credits=credits
            )
            class_options_dict[nrc] = new_option
            all_options_by_subject[code].append(new_option)

        if dia and hora_inicio and hora_final:
            hora_inicio_str = hora_inicio.strftime("%H:%M")
            hora_final_str = hora_final.strftime("%H:%M")
            class_options_dict[nrc].schedules.append(
                Schedule(day=dia, time=f"{hora_inicio_str} - {hora_final_str}")
            )

    # --- Lógica de combinación ---
    # SOLUCIÓN: Especificar el tipo de la lista al inicializarla
    combinations_per_subject: List[List[List[ClassOption]]] = []
    for code in subject_codes:
        subject_options = all_options_by_subject.get(code, [])
        if subject_options:
            combinations = _get_option_combinations(subject_options)
            if combinations:
                combinations_per_subject.append(combinations)
            
    return combinations_per_subject

# SOLUCIÓN: Eliminar 'async' y especificar el tipo de retorno del diccionario
def get_all_subjects_summary() -> List[Dict[str, Any]]:
    # Conectar a la base de datos de forma explícita
    conn = psycopg.connect(
        dbname=db_name,
        user=db_user,
        password=db_password,
        host=db_host,
        port=db_port
    )
    # Usamos dict_row para que la BD devuelva diccionarios directamente
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)
    
    cursor.execute("SELECT CodigoMateria as code, Nombre as name, Creditos as credits FROM Materia ORDER BY Nombre;")
    
    subjects = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    # Convertimos el resultado a una lista de diccionarios estándar
    return [dict(s) for s in subjects]