import sys
import json
import os
# Importa la función de conexión en lugar de la configuración antigua.
from config import get_connection
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from app.models import Subject, ClassOption, Schedule

def exportar_subjects_a_json():
    """
    Consulta la base de datos, construye los objetos de materia y los exporta a un archivo JSON.
    """
    # Usa la función centralizada para obtener la conexión.
    conn = get_connection()
    cursor = conn.cursor()
    try: 
        cursor.execute("""
            SELECT 
                m.CodigoMateria,
                m.Nombre,
                m.Creditos,
                c.NRC,
                c.Tipo,
                c.GroupID,
                c.Campus,
                c.CuposDisponibles,
                c.CuposTotales,
                p.Nombre AS Profesor,
                cl.Dia,
                cl.HoraInicio,
                cl.HoraFinal
            FROM Materia m
            JOIN Curso c ON m.CodigoMateria = c.CodigoMateria
            LEFT JOIN Profesor p ON c.ProfesorID = p.BannerID
            LEFT JOIN Clase cl ON cl.NRC = c.NRC
            ORDER BY 
            m.CodigoMateria,
            c.GroupID,
            c.NRC,
            CASE cl.Dia
                WHEN 'Lunes' THEN 1
                WHEN 'Martes' THEN 2
                WHEN 'Miércoles' THEN 3
                WHEN 'Jueves' THEN 4
                WHEN 'Viernes' THEN 5
                WHEN 'Sábado' THEN 6
                WHEN 'Domingo' THEN 7
                ELSE 8
            END,
            cl.HoraInicio;
        """)

        rows = cursor.fetchall()

        subjects_dict: dict[str, Subject] = {}
        class_options_dict: dict[str, ClassOption] = {}

        for row in rows:
            (
                code, name, credits, nrc_val, tipo, group_id, campus, 
                cupos_disponibles, cupos_totales, profesor, dia, 
                hora_inicio, hora_final
            ) = row
            
            nrc = str(nrc_val)

            # Si la materia no existe en nuestro diccionario, la creamos.
            if code not in subjects_dict:
                subjects_dict[code] = Subject(code=code, name=name, credits=credits, classOptions=[])

            # Si la opción de clase (curso) no existe, la creamos y la añadimos a su materia.
            if nrc not in class_options_dict:
                new_option = ClassOption(
                    subjectName=name, subjectCode=code, type=tipo, schedules=[],
                    professor=profesor or "Por Asignar", nrc=nrc, groupId=group_id,
                    credits=credits, campus=campus or "N/A",
                    seatsAvailable=cupos_disponibles, seatsMaximum=cupos_totales
                )
                class_options_dict[nrc] = new_option
                subjects_dict[code].class_options.append(new_option)

            # Añade el horario a la opción de clase correspondiente.
            if dia and hora_inicio and hora_final:
                hora_inicio_str = hora_inicio.strftime("%H:%M")
                hora_final_str = hora_final.strftime("%H:%M")
                class_options_dict[nrc].schedules.append(
                    Schedule(day=dia, time=f"{hora_inicio_str} - {hora_final_str}")
                )

        # Convertir a lista compatible con JSON
        subjects_list = [subj.model_dump(by_alias=True) for subj in subjects_dict.values()]

        # La ruta de exportación debe ser accesible desde el contenedor
        EXPORT_DIR = os.path.join(os.path.dirname(__file__), "shared_data")
        os.makedirs(EXPORT_DIR, exist_ok=True)
        filepath = os.path.join(EXPORT_DIR, "subject_data.json")

        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(subjects_list, f, ensure_ascii=False, indent=2)

        print(f"Archivo '{filepath}' generado correctamente.")

    finally:
        cursor.close()
        conn.close()

# Permite ejecutar el script directamente para pruebas
if __name__ == '__main__':
    try:
        exportar_subjects_a_json()
    except Exception as e:
        print(f"Ocurrió un error al exportar a JSON: {e}")

