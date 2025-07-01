# insertar_en_db.py
import json
import os
from config import get_connection
from backup import respaldar_datos, limpiar_tablas, hacer_snapshot
from parser import procesar_json
from inserter import insertar_datos

def guardar_log(errores):
    if not errores:
        return
    os.makedirs("logs", exist_ok=True)
    with open("logs/log.txt", "a", encoding="utf-8") as f:
        for err in errores:
            f.write(err + "\n")
    print(f"Se registraron {len(errores)} errores en logs/log.txt")

def actualizar_base():
    ruta_json = os.path.join(os.path.dirname(__file__), "search_results_complete.json")
    if not os.path.exists(ruta_json):
        raise FileNotFoundError("No se encontró el archivo search_results_complete.json")

    with open(ruta_json, encoding="utf-8") as f:
        json_data = json.load(f)

    conn = get_connection()

    hacer_snapshot()
    print("Respaldando y limpiando datos anteriores...")
    respaldar_datos(conn)
    limpiar_tablas(conn)

    print("Procesando JSON...")
    datos = procesar_json(json_data)

    print("Insertando nuevos datos...")
    insertar_datos(conn, datos)

    guardar_log(datos['errores'])

    conn.close()
    print("Base de datos actualizada con éxito.")
