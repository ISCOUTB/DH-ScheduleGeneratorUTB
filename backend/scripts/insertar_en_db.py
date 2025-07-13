# insertar_en_db.py
import json
import os
from config import get_connection
from backup import limpiar_tablas, hacer_snapshot
from parser import procesar_json
from inserter import insertar_datos

def guardar_log(errores: list[str]):
    """
    Guarda los errores en un archivo de log.
    """
    if not errores:
        return
    EXPORT_DIR = os.path.join(os.path.dirname(__file__), "logs")
    os.makedirs(EXPORT_DIR, exist_ok=True)
    with open(f"{EXPORT_DIR}/log.txt", "a", encoding="utf-8") as f:
        for err in errores:
            f.write(err + "\n")
    print(f"Se registraron {len(errores)} errores en {EXPORT_DIR}/log.txt")

def actualizar_base():

    # Actualiza la base de datos con los datos del JSON.
    IMPORT_DIR = os.path.join(os.path.dirname(__file__), "data_scrapped")
    os.makedirs(IMPORT_DIR, exist_ok=True)
    ruta_json = os.path.join(IMPORT_DIR, "search_results_complete.json")
    
    if not os.path.exists(ruta_json):
        raise FileNotFoundError("No se encontró el archivo search_results_complete.json")

    with open(ruta_json, encoding="utf-8") as f:
        json_data = json.load(f)

    conn = get_connection()

    print("Creando snapshot de la base de datos...")
    hacer_snapshot()
    
    print("Limpiando tablas...")
    limpiar_tablas(conn)

    print("Procesando JSON...")
    datos = procesar_json(json_data)

    print("Insertando nuevos datos...")
    insertar_datos(conn, datos)

    guardar_log(datos['errores'])

    conn.close()
    print("Base de datos actualizada con éxito.")
