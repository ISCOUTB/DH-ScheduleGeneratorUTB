# backup.py
import os
import subprocess
import psycopg
from typing import Any
from config import get_connection, DATABASE_URL 
from utils import timestamp_actual


# Oferta del periodo: se limpia y se reinserta en cada ETL. NO incluye `Materia`:
# desde los cursos personalizados, `Materia` es un catálogo persistente (una
# materia debe sobrevivir aunque pierda todos sus cursos, para que un curso
# personalizado la pueda referenciar). Ver docs/issues/17-07-2026-rfc-cursos-personalizados.md
# El orden respeta las FK: Clase->Curso, Curso->Profesor/Materia.
ACADEMIC_TABLES = (
    "Clase",
    "Curso",
    "Profesor",
)

# Tablas funcionales de la aplicación que no deben limpiarse durante ETL académico.
# `Materia` va aquí ahora: es catálogo, no oferta.
PRESERVED_APP_TABLES = (
    "usuario",
    "sesion_usuario",
    "horario_destacado",
    "materia",
)


def limpiar_tablas(conn: psycopg.Connection, auto_commit: bool = True):
    """
    Limpia solo las tablas académicas de oferta.

    Importante:
    - No limpia tablas funcionales de aplicación (ej. `usuario`).
    - Esto permite persistir identidad y preferencias entre actualizaciones ETL.
    """
    with conn.cursor() as cursor:
        for table_name in ACADEMIC_TABLES:
            cursor.execute(f"DELETE FROM {table_name}")

    if auto_commit:
        conn.commit()

    print(f"Tablas académicas limpiadas: {', '.join(ACADEMIC_TABLES)}")
    print(f"Tablas preservadas: {', '.join(PRESERVED_APP_TABLES)}")

def hacer_snapshot():
    """Crea un snapshot de la base de datos usando pg_dump, enfocado en tablas funcionales (usuarios, etc)."""
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

    # Agregar explícitamente las tablas funcionales que queremos respaldar
    for table in PRESERVED_APP_TABLES:
        comando.insert(-2, "-t")
        comando.insert(-2, table)

    try:
        print(f"Creando snapshot funcional ({', '.join(PRESERVED_APP_TABLES)})...")
        subprocess.run(comando, check=True, capture_output=True, text=True)
        print(f"Snapshot guardado en: {archivo_salida}")
        
        # Política de retención: mantener solo los últimos N snapshots para no llenar el disco
        # 1125 snapshots a 6 diarios cubren un poco más de 6 meses (~187 días)
        MAX_SNAPSHOTS = 1125
        archivos = sorted([os.path.join(export_dir, f) for f in os.listdir(export_dir) if f.startswith("snapshot_") and f.endswith(".sql")])
        if len(archivos) > MAX_SNAPSHOTS:
            para_borrar = archivos[:-MAX_SNAPSHOTS]
            for archivo in para_borrar:
                os.remove(archivo)
                print(f"Snapshot antiguo eliminado: {archivo}")
                
    except FileNotFoundError:
        print("Error: El comando 'pg_dump' no se encontró. Asegúrate de que postgresql-client esté instalado en el contenedor.")
    except subprocess.CalledProcessError as e:
        print(f"Error al crear snapshot: {e.stderr}")

if __name__ == '__main__':
    try:
        # Solo ejecutamos el snapshot (ya no limpiamos las tablas aquí, eso es tarea del ETL)
        hacer_snapshot()
    except Exception as e:
        print(f"Ocurrió un error: {e}")

