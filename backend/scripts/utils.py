# utils.py
import html
import re
from datetime import datetime

def formatear_hora(hhmm):
    if not hhmm or len(hhmm) != 4:
        return None
    return f"{hhmm[:2]}:{hhmm[2:]}"

def limpiar_nombre(texto):
    if not texto:
        return ""
    texto = html.unescape(texto).strip()
    texto = re.sub(r'\s+', ' ', texto)
    return capitalizar_con_tildes(texto)

def capitalizar_con_tildes(texto):
    return ' '.join([
        palabra.capitalize() if not palabra.isupper() else palabra
        for palabra in texto.lower().split()
    ])

def obtener_dias(meeting_time):
    dias = []
    dias_map = {
        'monday': 'Lunes',
        'tuesday': 'Martes',
        'wednesday': 'Miércoles',
        'thursday': 'Jueves',
        'friday': 'Viernes',
        'saturday': 'Sábado',
        'sunday': 'Domingo'
    }
    for clave_json, nombre_dia in dias_map.items():
        if meeting_time.get(clave_json):
            dias.append(nombre_dia)
    return dias

def timestamp_actual():
    return datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
