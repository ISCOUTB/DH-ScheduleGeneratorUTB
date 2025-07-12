# backup.py
import os
import subprocess
import psycopg
from config import DB_CONFIG
from utils import timestamp_actual


def limpiar_tablas(conn: psycopg.Connection):
    """Limpia las tablas de la base de datos.
    """
    cursor = conn.cursor()
    cursor.execute("DELETE FROM Clase")
    cursor.execute("DELETE FROM Curso")
    cursor.execute("DELETE FROM Profesor")
    cursor.execute("DELETE FROM Materia")
    conn.commit()
    print("Tablas limpiadas correctamente.")

def hacer_snapshot():
    timestamp = timestamp_actual()
    EXPORT_DIR = os.path.join(os.path.dirname(__file__), "snapshots")
    os.makedirs(EXPORT_DIR, exist_ok=True)
    archivo_salida = f"{EXPORT_DIR}/snapshot_{timestamp}.sql"

    os.environ['PGPASSWORD'] = DB_CONFIG['password']

    comando: list[str] = [
        "pg_dump",
        "-U", DB_CONFIG['user'],
        "-h", DB_CONFIG.get('host', 'localhost'),
        "-p", str(DB_CONFIG.get('port', 5432)),
        "-d", DB_CONFIG['dbname'],
        "-f", archivo_salida
    ]

    try:
        print("Creando snapshot completo de la base de datos...")
        subprocess.run(comando, check=True)
        print(f"Snapshot guardado en: {archivo_salida}")
    except subprocess.CalledProcessError as e:
        print(f" Error al crear snapshot: {e}")

