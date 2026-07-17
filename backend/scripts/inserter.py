# insertar_en_db.py
import psycopg
from parser import ProcesarJsonResponse

def insertar_datos(conn: psycopg.Connection, datos: ProcesarJsonResponse, auto_commit: bool = True) -> None:
    cursor = conn.cursor()

    # `Materia` ya no se limpia entre ETLs (es catálogo persistente, ver
    # backup.py). Por eso el INSERT es un upsert: si la materia ya existe
    # (misma PK código+nombre) se conserva y solo se refrescan los créditos.
    # No se "actualiza el nombre": un renombre en Banner es indistinguible de
    # una variante nueva (mismo código, otro nombre), así que crea una fila
    # nueva y la vieja queda como descontinuada. Ver RFC §3.1.
    for m in datos['materias']:
        cursor.execute(
            """
            INSERT INTO Materia (CodigoMateria, Creditos, Nombre)
            VALUES (%s, %s, %s)
            ON CONFLICT (CodigoMateria, Nombre)
            DO UPDATE SET Creditos = EXCLUDED.Creditos
            """,
            m,
        )

    for p in datos['profesores']:
        cursor.execute("INSERT INTO Profesor (BannerID, Nombre) VALUES (%s, %s)", p)

    # Separa cursos teóricos y laboratorios
    cursos_teoricos = [c for c in datos['cursos'] if c[1] == "Teórico"]
    cursos_lab = [c for c in datos['cursos'] if c[1] == "Laboratorio"]

    # Insertar teóricos primero
    for c in cursos_teoricos:
        cursor.execute("""
            INSERT INTO Curso (NRC, Tipo, CodigoMateria, ProfesorID, NRCTeorico, GroupID, Campus, CuposDisponibles, CuposTotales, NombreMateria)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, c)

    # Luego insertar laboratorios
    for c in cursos_lab:
        cursor.execute("""
            INSERT INTO Curso (NRC, Tipo, CodigoMateria, ProfesorID, NRCTeorico, GroupID, Campus, CuposDisponibles, CuposTotales, NombreMateria)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, c)

    for cl in datos['clases']:
        cursor.execute("""
            INSERT INTO Clase (NRC, HoraInicio, HoraFinal, Aula, Dia)
            VALUES (%s, %s, %s, %s, %s)
        """, cl)

    if auto_commit:
        conn.commit()

    print("Datos insertados correctamente.")