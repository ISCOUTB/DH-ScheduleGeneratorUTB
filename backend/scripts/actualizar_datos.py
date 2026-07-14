import os
import sys
from descargar_json import descargar_json
from insertar_en_db import actualizar_base
from export_to_subject_json import exportar_subjects_a_json
from migrar_esquema import aplicar_migraciones

def main():

    # Antes de tocar los datos: el esquema de una base ya creada no lo actualiza
    # init.sql (solo corre con el volumen vacío). Es idempotente.
    print("Verificando esquema de la base...")
    aplicar_migraciones()

    print("Descargando JSON crudo desde Banner...")
    try:
        descargar_json()  # Genera search_results_complete.json
    except Exception as e:
        # Banner caído/incompleto: se omite este ciclo SIN tocar la base. El
        # cron reintentará en la próxima corrida. NO se continúa al ETL porque
        # limpiaría la oferta académica.
        print(f"Actualización OMITIDA (descarga fallida, datos preservados): {e}")
        return
    print("JSON descargado.")

    print("Insertando datos en la base...")
    actualizar_base()
    print("Datos insertados correctamente.")

    print("Exportando JSON limpio para la API...")
    exportar_subjects_a_json()
    print("Listo: subject_data.json generado.")

if __name__ == "__main__":

    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
    main()
