"""
Módulo de repositorio para interactuar con la base de datos PostgreSQL.
Gestiona las consultas para obtener información sobre materias, cursos y horarios.
"""
import psycopg
import psycopg.rows
import json
import os
from dotenv import load_dotenv
from typing import List, Dict, Any, Optional
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
                # Creditos es NUMERIC en la base (créditos fraccionarios) y psycopg
                # lo devuelve como Decimal, que no se puede sumar con floats.
                credits=float(credits),
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
        "credits": float(rows[0][2]),
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
                credits=float(credits),
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
    Materias que tienen oferta en el periodo actual (código, nombre, créditos).

    Es la lista del buscador. Antes salía de `Materia` a secas, pero desde que
    `Materia` es catálogo persistente (ver RFC cursos personalizados) puede tener
    materias sin cursos; el buscador solo debe mostrar las que sí se ofertan, así
    que se une con `Curso`. Para el catálogo completo, ver
    `get_all_subjects_catalog`.
    """
    conn = get_db_connection()
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)

    cursor.execute(
        """
        SELECT DISTINCT m.CodigoMateria AS code, m.Nombre AS name, m.Creditos AS credits
        FROM Materia m
        JOIN Curso c
          ON c.CodigoMateria = m.CodigoMateria AND c.NombreMateria = m.Nombre
        ORDER BY m.Nombre;
        """
    )

    subjects = cursor.fetchall()

    cursor.close()
    conn.close()

    # Creditos es NUMERIC (créditos fraccionarios): se expone como número JSON,
    # no como el Decimal que devuelve psycopg.
    return [{**s, "credits": float(s["credits"])} for s in subjects]


def get_all_subjects_catalog() -> List[Dict[str, Any]]:
    """
    TODAS las materias del catálogo, tengan oferta o no (código, nombre, créditos).

    Es la lista para el selector de materia de un curso personalizado: ahí sí se
    permite elegir una materia que ya no tiene cursos en la oferta actual (ese es
    justamente el caso de uso). El buscador normal usa `get_all_subjects_summary`.
    """
    conn = get_db_connection()
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)

    cursor.execute(
        "SELECT CodigoMateria AS code, Nombre AS name, Creditos AS credits FROM Materia ORDER BY Nombre;"
    )

    subjects = cursor.fetchall()

    cursor.close()
    conn.close()

    return [{**s, "credits": float(s["credits"])} for s in subjects]


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
            updates: List[str] = []
            params: List[Any] = []

            # Mantener datos sincronizados con Entra en cada login.
            if email and user.get("email") != email:
                updates.append("email = %s")
                params.append(email)

            if nombre is not None and user.get("nombre") != nombre:
                updates.append("nombre = %s")
                params.append(nombre)

            if updates:
                update_sql = f"UPDATE usuario SET {', '.join(updates)} WHERE entra_id = %s"
                params.append(entra_id)
                cursor.execute(update_sql, tuple(params))
                conn.commit()

                user = dict(user)

                if email:
                    user["email"] = email
                if nombre is not None:
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


def register_login(usuario_id: int, ip_address: str = None, user_agent: str = None, tipo: str = "login"):
    """
    Registra un inicio de sesión o visita del usuario.
    Guarda la fecha/hora, dirección IP, user-agent del navegador y tipo de evento.
    
    tipo: 'login' para autenticación OAuth, 'visita' para apertura con sesión existente.
    """
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            "INSERT INTO sesion_usuario (usuario_id, ip_address, user_agent, tipo) VALUES (%s, %s, %s, %s)",
            (usuario_id, ip_address, user_agent, tipo)
        )
        conn.commit()
    except Exception as e:
        print(f"Error registrando inicio de sesión: {e}")
        conn.rollback()
    finally:
        cursor.close()
        conn.close()


# --- Funciones de Horarios Destacados (Favoritos) ---

def count_favorites(usuario_id: int, term: str) -> int:
    """Cuenta los favoritos de un usuario para un término dado."""
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            "SELECT COUNT(*) FROM horario_destacado WHERE usuario_id = %s AND term = %s",
            (usuario_id, term)
        )
        return cursor.fetchone()[0]
    finally:
        cursor.close()
        conn.close()


def create_favorite(usuario_id: int, term: str, signature: str, schedule_json: dict) -> Dict[str, Any] | None:
    """
    Crea un horario destacado. Si ya existe (mismo usuario, term, signature),
    retorna None para indicar duplicado.
    """
    conn = get_db_connection()
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)

    try:
        # `posicion` = la siguiente libre (al final): un destacado nuevo va al
        # final de la cola, sin renombrar los existentes.
        cursor.execute(
            """
            INSERT INTO horario_destacado (usuario_id, term, signature, schedule_json, posicion)
            VALUES (%s, %s, %s, %s::jsonb,
                COALESCE(
                    (SELECT MAX(posicion) + 1 FROM horario_destacado
                     WHERE usuario_id = %s AND term = %s), 0))
            ON CONFLICT (usuario_id, term, signature) DO NOTHING
            RETURNING id, usuario_id, term, signature, nombre, posicion, created_at
            """,
            (usuario_id, term, signature, json.dumps(schedule_json), usuario_id, term)
        )
        result = cursor.fetchone()
        conn.commit()
        return dict(result) if result else None
    finally:
        cursor.close()
        conn.close()


def get_favorites(usuario_id: int, term: str) -> List[Dict[str, Any]]:
    """Obtiene los horarios destacados de un usuario para un término, en el orden
    manual guardado (`posicion`)."""
    conn = get_db_connection()
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)

    try:
        cursor.execute(
            """
            SELECT id, usuario_id, term, signature, nombre, posicion, schedule_json, created_at
            FROM horario_destacado
            WHERE usuario_id = %s AND term = %s
            ORDER BY posicion ASC NULLS LAST, created_at ASC, id ASC
            """,
            (usuario_id, term)
        )
        return [dict(row) for row in cursor.fetchall()]
    finally:
        cursor.close()
        conn.close()


def rename_favorite(favorite_id: int, usuario_id: int, nombre: Optional[str]) -> bool:
    """Renombra un destacado (o quita el nombre si `nombre` es None/''). Valida
    dueño. Retorna True si actualizó una fila."""
    limpio = (nombre or "").strip() or None
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "UPDATE horario_destacado SET nombre = %s WHERE id = %s AND usuario_id = %s",
            (limpio, favorite_id, usuario_id),
        )
        conn.commit()
        return cursor.rowcount > 0
    finally:
        cursor.close()
        conn.close()


def reorder_favorites(usuario_id: int, term: str, ordered_ids: List[int]) -> bool:
    """Asigna `posicion` = índice a cada favorito según el orden recibido. Solo
    toca filas del propio usuario y término (los IDs ajenos se ignoran)."""
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        for pos, fid in enumerate(ordered_ids):
            cursor.execute(
                "UPDATE horario_destacado SET posicion = %s "
                "WHERE id = %s AND usuario_id = %s AND term = %s",
                (pos, fid, usuario_id, term),
            )
        conn.commit()
        return True
    finally:
        cursor.close()
        conn.close()


def delete_favorite(favorite_id: int, usuario_id: int) -> bool:
    """
    Elimina un favorito por ID, validando que pertenezca al usuario.
    Retorna True si se eliminó, False si no existía o no pertenecía al usuario.
    """
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            "DELETE FROM horario_destacado WHERE id = %s AND usuario_id = %s",
            (favorite_id, usuario_id)
        )
        conn.commit()
        return cursor.rowcount > 0
    finally:
        cursor.close()
        conn.close()


def get_favorite_terms(usuario_id: int) -> List[str]:
    """Obtiene los términos distintos que tienen favoritos para un usuario."""
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            """
            SELECT DISTINCT term
            FROM horario_destacado
            WHERE usuario_id = %s
            ORDER BY term DESC
            """,
            (usuario_id,)
        )
        return [row[0] for row in cursor.fetchall()]
    finally:
        cursor.close()
        conn.close()


# --- Funciones de Estado de Cursos (Fase 2: estado visual de cupos) ---

def get_nrc_seats(nrcs: List[str]) -> Dict[str, Dict[str, int]]:
    """
    Consulta los cupos actuales de una lista de NRCs en la tabla Curso.

    Solo refleja el término vigente: la tabla Curso se reescribe en cada corrida
    del ETL, por lo que esta función únicamente tiene sentido para el término
    actual (ver RFC Fase 2, sección 2.6).

    Retorna { nrc(str): {"available": int, "total": int} }.
    Los NRC no numéricos se ignoran; los inexistentes en Curso no aparecen
    (el frontend los trata como 'eliminado').
    """
    # El NRC es entero en BD; descartamos lo no numérico antes de consultar.
    nrc_ints = [int(n) for n in nrcs if str(n).isdigit()]
    if not nrc_ints:
        return {}

    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute(
            "SELECT NRC, CuposDisponibles, CuposTotales FROM Curso WHERE NRC = ANY(%s)",
            (nrc_ints,)
        )
        return {
            str(nrc): {"available": disponibles, "total": totales}
            for (nrc, disponibles, totales) in cursor.fetchall()
        }
    finally:
        cursor.close()
        conn.close()


# --- Cursos personalizados (por usuario) ---

def _shape_custom_course(row: Dict[str, Any]) -> Dict[str, Any]:
    """Da forma a una fila de `curso_personalizado` para la API.

    El NRC efectivo es el del usuario o, si no lo puso, uno sintético ``CP{id}``:
    estable y sin colisión con los NRC reales (numéricos). Ese prefijo también
    sirve para distinguir un curso personalizado del resto (ej. no marcarlo como
    'fuera de la oferta' en el aviso de destacados).
    """
    return {
        "id": row["id"],
        "code": row["codigomateria"],
        "name": row["nombremateria"],
        "credits": float(row["creditos"]) if row.get("creditos") is not None else 0.0,
        "etiqueta": row.get("etiqueta"),
        "nrc": row["nrc"] or f"CP{row['id']}",
        "type": row.get("tipo"),
        "professor": row.get("profesor"),
        "campus": row.get("campus"),
        "activo": row["activo"],
        "bloques": row["bloques"],
        "created_at": str(row["created_at"]) if row.get("created_at") else None,
    }


def get_nrc_subject(nrc: str) -> Optional[Dict[str, str]]:
    """Materia (código, nombre) que ocupa un NRC en la oferta actual, o None.

    Sirve para bloquear un curso personalizado con un NRC que ya existe: no se
    puede reusar un NRC real. El NRC es entero en BD; lo no numérico nunca
    colisiona (un NRC sintético 'CP...' no aplica).
    """
    if not str(nrc).isdigit():
        return None
    conn = get_db_connection()
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)
    try:
        cursor.execute(
            "SELECT CodigoMateria AS code, NombreMateria AS name FROM Curso WHERE NRC = %s LIMIT 1",
            (int(nrc),),
        )
        row = cursor.fetchone()
        return dict(row) if row else None
    finally:
        cursor.close()
        conn.close()


def materia_exists(codigo: str, nombre: str) -> bool:
    """¿Existe la materia (par código, nombre) en el catálogo?"""
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT 1 FROM Materia WHERE CodigoMateria = %s AND Nombre = %s",
            (codigo, nombre),
        )
        return cursor.fetchone() is not None
    finally:
        cursor.close()
        conn.close()


def _fetch_custom_course(cursor, id_: int, usuario_id: int):
    """Lee un curso personalizado con los créditos de su materia. Valida dueño."""
    cursor.execute(
        """
        SELECT cp.*, m.Creditos AS creditos
        FROM curso_personalizado cp
        LEFT JOIN Materia m
          ON m.CodigoMateria = cp.codigomateria AND m.Nombre = cp.nombremateria
        WHERE cp.id = %s AND cp.usuario_id = %s
        """,
        (id_, usuario_id),
    )
    row = cursor.fetchone()
    return _shape_custom_course(row) if row else None


def count_custom_courses(usuario_id: int) -> int:
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT COUNT(*) FROM curso_personalizado WHERE usuario_id = %s",
            (usuario_id,),
        )
        return cursor.fetchone()[0]
    finally:
        cursor.close()
        conn.close()


def get_custom_courses(usuario_id: int) -> List[Dict[str, Any]]:
    """Todos los cursos personalizados del usuario, agrupables por materia."""
    conn = get_db_connection()
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)
    try:
        cursor.execute(
            """
            SELECT cp.*, m.Creditos AS creditos
            FROM curso_personalizado cp
            LEFT JOIN Materia m
              ON m.CodigoMateria = cp.codigomateria AND m.Nombre = cp.nombremateria
            WHERE cp.usuario_id = %s
            ORDER BY cp.nombremateria, cp.id
            """,
            (usuario_id,),
        )
        return [_shape_custom_course(r) for r in cursor.fetchall()]
    finally:
        cursor.close()
        conn.close()


def create_custom_course(
    usuario_id: int, codigo: str, nombre: str, bloques: list,
    nrc: str = None, tipo: str = None, profesor: str = None,
    campus: str = None, activo: bool = True, etiqueta: str = None,
) -> Dict[str, Any]:
    conn = get_db_connection()
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)
    try:
        cursor.execute(
            """
            INSERT INTO curso_personalizado
                (usuario_id, codigomateria, nombremateria, etiqueta, nrc, tipo, profesor, campus, activo, bloques)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb)
            RETURNING id
            """,
            (usuario_id, codigo, nombre, etiqueta, nrc, tipo, profesor, campus, activo, json.dumps(bloques)),
        )
        new_id = cursor.fetchone()["id"]
        result = _fetch_custom_course(cursor, new_id, usuario_id)
        conn.commit()
        return result
    finally:
        cursor.close()
        conn.close()


def update_custom_course(
    id_: int, usuario_id: int, bloques=None, nrc=None, tipo=None,
    profesor=None, campus=None, activo=None, etiqueta=None,
) -> Dict[str, Any] | None:
    """Actualiza los campos provistos (None = no tocar). Valida dueño.

    Retorna el curso actualizado, o None si no existe / no es del usuario.
    """
    sets: List[str] = []
    params: List[Any] = []
    if bloques is not None:
        sets.append("bloques = %s::jsonb")
        params.append(json.dumps(bloques))
    if etiqueta is not None:
        sets.append("etiqueta = %s")
        params.append(etiqueta)
    if nrc is not None:
        sets.append("nrc = %s")
        params.append(nrc)
    if tipo is not None:
        sets.append("tipo = %s")
        params.append(tipo)
    if profesor is not None:
        sets.append("profesor = %s")
        params.append(profesor)
    if campus is not None:
        sets.append("campus = %s")
        params.append(campus)
    if activo is not None:
        sets.append("activo = %s")
        params.append(activo)

    conn = get_db_connection()
    cursor = conn.cursor(row_factory=psycopg.rows.dict_row)
    try:
        if not sets:
            # Nada que cambiar; devolver el actual (o None si no es suyo).
            return _fetch_custom_course(cursor, id_, usuario_id)

        cursor.execute(
            # Los fragmentos de `sets` son fijos (nombres de columna del código);
            # todos los valores van parametrizados.
            f"UPDATE curso_personalizado SET {', '.join(sets)} WHERE id = %s AND usuario_id = %s",
            params + [id_, usuario_id],
        )
        if cursor.rowcount == 0:
            conn.rollback()
            return None
        result = _fetch_custom_course(cursor, id_, usuario_id)
        conn.commit()
        return result
    finally:
        cursor.close()
        conn.close()


def delete_custom_course(id_: int, usuario_id: int) -> bool:
    """Elimina un curso personalizado. Valida dueño."""
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "DELETE FROM curso_personalizado WHERE id = %s AND usuario_id = %s",
            (id_, usuario_id),
        )
        conn.commit()
        return cursor.rowcount > 0
    finally:
        cursor.close()
        conn.close()