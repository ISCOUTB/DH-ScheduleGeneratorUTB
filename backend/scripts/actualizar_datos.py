from descargar_json import descargar_json
from insertar_en_db import actualizar_base
from export_to_subject_json import exportar_subjects_a_json

def main():
    print("Descargando JSON crudo desde Banner...")
    descargar_json()  # Genera search_results_complete.json
    print("JSON descargado.")

    print("Insertando datos en la base...")
    actualizar_base()
    print("Datos insertados correctamente.")

    print("Exportando JSON limpio para la API...")
    exportar_subjects_a_json()
    print("Listo: subject_data.json generado.")

if __name__ == "__main__":
    main()
