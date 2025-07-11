import psycopg
import json
import os
from config import DB_CONFIG  # Asegúrate de que config.py tenga los datos correctos
from app.models import Subject, ClassOption, Schedule

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
            c.Campus,
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

    # Estructura: { subjectCode: { ...materia..., classOptions: { NRC: {...} } } }
    subjects_dict: dict[str, Subject] = {}

    for row in rows:
        code, name, credits, nrc, tipo, group_id, campus, profesor, dia, hora_inicio, hora_final = row

        # Inicializar materia si es nueva
        if code not in subjects_dict:
            subjects_dict[code] = Subject(
                code=code,
                name=name,
                credits=credits,
                classOptions=[]
            )

        subj = subjects_dict[code]
        nrc_str = str(nrc)

        exist_nrc = any(op.nrc == nrc_str for op in subj.class_options)

        if not exist_nrc:
            nueva_opcion = ClassOption(
                subjectName=name,
                subjectCode=code,
                type=tipo,
                schedules=[],
                professor=profesor or "",
                nrc=nrc_str,
                groupId=group_id,
                credits=credits,
                campus=campus or ""
            )
            subj.class_options.append(nueva_opcion)

        # Obtener la clase correspondiente
        clase = next((op for op in subj.class_options if op.nrc == nrc_str), None)

        # Añadir horario si existe
        if clase and dia and hora_inicio and hora_final:
            hora_inicio_str = hora_inicio.strftime("%H:%M")
            hora_final_str = hora_final.strftime("%H:%M")
            clase.schedules.append(Schedule(
                day=dia,
                time=f"{hora_inicio_str} - {hora_final_str}"
            ))


    # Convertir a lista compatible con JSON
    subjects_list = [
        subj_data.model_dump(by_alias=True)
        for subj_data in subjects_dict.values()
    ]

    EXPORT_DIR = os.path.join(os.path.dirname(__file__), "shared_data")
    os.makedirs(EXPORT_DIR, exist_ok=True)

    filepath = os.path.join(EXPORT_DIR, "subject_data.json")

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(subjects_list, f, ensure_ascii=False, indent=2)

    print("Archivo 'subject_data.json' generado correctamente.")

    cursor.close()
    conn.close()

    


