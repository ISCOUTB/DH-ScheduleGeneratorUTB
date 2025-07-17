# backup.py
import os
import subprocess
import psycopg
from typing import Any
from config import get_connection, DATABASE_URL 
from utils import timestamp_actual


def limpiar_tablas(conn: psycopg.Connection):
    """Limpia las tablas de la base de datos."""
    with conn.cursor() as cursor:
        cursor.execute("DELETE FROM Clase")
        cursor.execute("DELETE FROM Curso")
        cursor.execute("DELETE FROM Profesor")
        cursor.execute("DELETE FROM Materia")
    conn.commit()
    print("Tablas limpiadas correctamente.")

def hacer_snapshot():
    """Crea un snapshot de la base de datos usando pg_dump y la DATABASE_URL."""
    timestamp = timestamp_actual()
    export_dir = os.path.join(os.path.dirname(__file__), "snapshots")
    os.makedirs(export_dir, exist_ok=True)
    archivo_salida = os.path.join(export_dir, f"snapshot_{timestamp}.sql")

    comando: list[Any] = [
        "pg_dump",
        DATABASE_URL,
        "-f",
        archivo_salida
    ]

    try:
        print("Creando snapshot completo de la base de datos...")
        subprocess.run(comando, check=True, capture_output=True, text=True)
        print(f"Snapshot guardado en: {archivo_salida}")
    except FileNotFoundError:
        print("Error: El comando 'pg_dump' no se encontró. Asegúrate de que postgresql-client esté instalado en el contenedor.")
    except subprocess.CalledProcessError as e:
        print(f"Error al crear snapshot: {e.stderr}")

if __name__ == '__main__':
    try:
        connection = get_connection()
        hacer_snapshot()
        limpiar_tablas(connection)
        connection.close()
    except Exception as e:
        print(f"Ocurrió un error: {e}")

