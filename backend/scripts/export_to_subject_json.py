import psycopg
import json
import os
from config import DB_CONFIG  # Asegúrate de que config.py tenga los datos correctos


def exportar_subjects_a_json():
    conn = psycopg.connect(**DB_CONFIG)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT 
            m.CodigoMateria,
            m.Nombre,
            m.Creditos,
            c.NRC,
            c.Tipo,
            c.GroupID,
            p.Nombre AS Profesor,
            cl.Dia,
            cl.HoraInicio,
            cl.HoraFinal
        FROM Materia m
        JOIN Curso c ON m.CodigoMateria = c.CodigoMateria
        LEFT JOIN Profesor p ON c.ProfesorID = p.BannerID
        LEFT JOIN Clase cl ON cl.NRC = c.NRC
        ORDER BY m.CodigoMateria, c.GroupID, c.NRC, cl.Dia, cl.HoraInicio
    """)

    rows = cursor.fetchall()

    # Estructura: { subjectCode: { ...materia..., classOptions: { NRC: {...} } } }
    subjects_dict: dict[str, dict] = {}

    for row in rows:
        code, name, credits, nrc, tipo, group_id, profesor, dia, hora_inicio, hora_final = row

        # Inicializar materia si es nueva
        if code not in subjects_dict:
            subjects_dict[code] = {
                "code": code,
                "name": name,
                "credits": credits,
                "classOptions": {}
            }

        subj = subjects_dict[code]

        # Inicializar opción de clase si es nueva
        if nrc not in subj["classOptions"]:
            subj["classOptions"][nrc] = {
                "subjectCode": code,
                "subjectName": name,
                "type": tipo,
                "credits": credits,
                "professor": profesor or "",
                "nrc": str(nrc),
                "groupId": group_id,
                "schedules": []
            }

        clase = subj["classOptions"][nrc]

        # Añadir horario si existe
        if dia and hora_inicio and hora_final:
            hora_inicio_str = hora_inicio.strftime("%H:%M")
            hora_final_str = hora_final.strftime("%H:%M")
            clase["schedules"].append({
                "day": dia,
                "time": f"{hora_inicio_str} - {hora_final_str}"
            })

    # Convertir a lista compatible con JSON
    subjects_list = []
    for subj_data in subjects_dict.values():
        class_options = list(subj_data["classOptions"].values())
        subject_dict = {
            "code": subj_data["code"],
            "name": subj_data["name"],
            "credits": subj_data["credits"],
            "classOptions": class_options
        }
        subjects_list.append(subject_dict)
    
    EXPORT_DIR = os.path.join(os.path.dirname(__file__), "shared_data")
    os.makedirs(EXPORT_DIR, exist_ok=True)

    filepath = os.path.join(EXPORT_DIR, "subject_data.json")

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(subjects_list, f, ensure_ascii=False, indent=2)

    print("Archivo 'subject_data.json' generado correctamente.")

    cursor.close()
    conn.close()

    


