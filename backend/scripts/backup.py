# backup.py
import os
import json
import subprocess
from config import DB_CONFIG
from utils import timestamp_actual

def serializar_fila(fila):
    serializada = {}
    for clave, valor in fila.items():
        if hasattr(valor, 'isoformat'):  # Para time, date, datetime
            serializada[clave] = valor.isoformat()
        else:
            serializada[clave] = valor
    return serializada

def respaldar_datos(conn):
    cursor = conn.cursor()
    tablas = ['Clase', 'Curso', 'Profesor', 'Materia']
    respaldo = {}

    for tabla in tablas:
        cursor.execute(f"SELECT * FROM {tabla}")
        columnas = [desc[0] for desc in cursor.description]
        filas = cursor.fetchall()
        respaldo[tabla] = [serializar_fila(dict(zip(columnas, fila))) for fila in filas]

    os.makedirs('respaldos', exist_ok=True)
    nombre_archivo = f"respaldos/{timestamp_actual()}.json"
    with open(nombre_archivo, 'w', encoding='utf-8') as f:
        json.dump(respaldo, f, ensure_ascii=False, indent=4)

    print(f"Respaldo guardado en: {nombre_archivo}")
    
def limpiar_tablas(conn):
    cursor = conn.cursor()
    cursor.execute("DELETE FROM Clase")
    cursor.execute("DELETE FROM Curso")
    cursor.execute("DELETE FROM Profesor")
    cursor.execute("DELETE FROM Materia")
    conn.commit()
    print("Tablas limpiadas correctamente.")

def hacer_snapshot():
    timestamp = timestamp_actual()
    os.makedirs("snapshots", exist_ok=True)
    archivo_salida = f"snapshots/snapshot_{timestamp}.sql"

    os.environ['PGPASSWORD'] = DB_CONFIG['password']

    comando = [
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

