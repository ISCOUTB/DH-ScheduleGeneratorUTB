# insertar_en_db.py
import json
import os
from config import get_connection
from backup import limpiar_tablas, hacer_snapshot
from parser import procesar_json
from inserter import insertar_datos
from rescatador import procesar_rescate

def guardar_log(errores: list[str], log_path: str):
    
    """
    Guarda los errores en un archivo de log.
    """
    if not errores:
        return
    
    # Asegurarse que el directorio de logs exista
    os.makedirs(os.path.dirname(log_path), exist_ok=True)

    with open(log_path, "w", encoding="utf-8") as f: # <--- Cambiado a "w" (write) para empezar limpio
        for err in errores:
            f.write(err + "\n")
    print(f"Se registraron {len(errores)} errores en {log_path}")

def actualizar_base():

    # --- CONFIGURACIÓN Y CARGA DE DATOS ---
    BASE_DIR = os.path.dirname(__file__)
    IMPORT_DIR = os.path.join(BASE_DIR, "data_scrapped")
    LOG_DIR = os.path.join(BASE_DIR, "logs")
    
    ruta_json = os.path.join(IMPORT_DIR, "search_results_complete.json")
    log_path = os.path.join(LOG_DIR, "log.txt") 
    # -- DEFINIR RUTA
    
    if not os.path.exists(ruta_json):
        raise FileNotFoundError("No se encontró el archivo search_results_complete.json")

    with open(ruta_json, encoding="utf-8") as f:
        json_data = json.load(f)

    # --- PREPARACIÓN DE LA BASE DE DATOS ---
    conn = get_connection()
    print("Creando snapshot de la base de datos...")
    hacer_snapshot()
    print("Limpiando tablas...")
    limpiar_tablas(conn)

    # --- PROCESAMIENTO Y RESCATE ---
    print("Paso 1: Procesando JSON inicial para detectar problemas...")
    datos_iniciales = procesar_json(json_data)
    
    # Guardamos el primer log para que el rescatador pueda leerlo
    guardar_log(datos_iniciales['errores'], log_path)

    print("\nPaso 2: Intentando rescatar cursos desde el log...")
    # Definimos el término de búsqueda.
    term = "202610" 
    # El rescatador devuelve el conjunto de datos final y curado.
    datos_finales = procesar_rescate(json_data, log_path, term)

    # --- INSERCIÓN Y CIERRE ---
    print("\nPaso 3: Insertando datos finales en la base de datos...")
    insertar_datos(conn, datos_finales)
    
    # Guardamos el log guardado, que ahora será más corto y preciso
    print("\nGuardando log de errores final...")
    guardar_log(datos_finales['errores'], log_path)

    conn.close()
    print("\nBase de datos actualizada con éxito.")