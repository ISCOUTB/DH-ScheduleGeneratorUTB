import requests
import re
from typing import Any, Optional, Dict
from parser import ProcesarJsonResponse, procesar_json

def extraer_nrc_del_log(log_path: str) -> set[str]:
    """Lee el archivo de log y extrae todos los NRC únicos."""
    nrcs: set[str] = set()
    try:
        with open(log_path, 'r', encoding='utf-8') as f:
            for line in f:
                # Expresión regular para encontrar 'NRC XXXXX'
                match = re.search(r'NRC (\d+)', line)
                if match:
                    nrcs.add(match.group(1))
    except FileNotFoundError:
        print(f"Advertencia: No se encontró el archivo de log en {log_path}")
    return nrcs

def rescatar_curso_ligado(session: requests.Session, term: str, nrc: str) -> Optional[Dict[str, Any]]:
    """
    Usa la petición 'fetchLinkedSections' para obtener la información de un curso ligado.
    """
    url = "https://bannerssbregistro.utb.edu.co:8443/StudentRegistrationSsb/ssb/searchResults/fetchLinkedSections"
    params = {
        "term": term,
        "courseReferenceNumber": nrc
    }
    try:
        response = session.get(url, params=params, verify=False, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        
        # Navega a la estructura correcta del JSON: data -> "linkedData" -> lista[0] -> lista[0]
        linked_data = data.get("linkedData")
        if linked_data and linked_data[0]:
            return linked_data[0][0] # Devuelve el primer curso de la lista anidada

    except requests.exceptions.RequestException as e:
        print(f"Error al rescatar NRC {nrc}: {e}")
    except (KeyError, IndexError) as e:
        print(f"Error al parsear la respuesta para NRC {nrc}. Estructura inesperada: {e}")
    return None

def procesar_rescate(json_original: Dict[str, Any], log_path: str, term: str) -> ProcesarJsonResponse:
    """
    Lee el log, rescata los JSON de los cursos faltantes, los añade al JSON original
    y vuelve a procesar todo para obtener un resultado final y curado.
    """
    print("--- Iniciando fase de rescate de cursos desde el log ---")
    nrcs_a_rescatar = extraer_nrc_del_log(log_path)
    if not nrcs_a_rescatar:
        print("No hay NRCs para rescatar en el log. Proceso finalizado.")
        # Si no hay nada que rescatar, devolvemos el resultado del parseo inicial
        return procesar_json(json_original)

    session = requests.Session()
    json_data_list = json_original['data']
    nrcs_existentes = {curso['courseReferenceNumber'] for curso in json_data_list}
    
    cursos_rescatados_con_exito = 0

    for nrc in nrcs_a_rescatar:
        print(f"Intentando rescatar par para NRC {nrc}...")
        curso_rescatado_json = rescatar_curso_ligado(session, term, nrc)
        
        if curso_rescatado_json:
            nrc_rescatado = curso_rescatado_json.get('courseReferenceNumber')
            print(f"  -> ¡Éxito! Se encontró el par para NRC {nrc}. NRC rescatado: {nrc_rescatado}")
            
            # Añadimos el curso rescatado al JSON original si no estaba ya
            if nrc_rescatado not in nrcs_existentes:
                json_data_list.append(curso_rescatado_json)
                nrcs_existentes.add(nrc_rescatado)
                cursos_rescatados_con_exito += 1
        else:
            # Este NRC no tiene par, el segundo parseo lo marcará como error definitivo.
            print(f"  -> Fallo. No se encontró par para NRC {nrc}. Se marcará como error final.")

    if cursos_rescatados_con_exito > 0:
        print(f"\nSe rescataron {cursos_rescatados_con_exito} cursos. Re-procesando el JSON completo...")
        json_curado = {"data": json_data_list}
        return procesar_json(json_curado)
    else:
        print("\nNo se pudo rescatar ningún curso nuevo. Devolviendo resultados iniciales.")
        return procesar_json(json_original)