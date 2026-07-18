import requests
import re
from typing import Any, Dict, List
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

def rescatar_cursos_ligados(session: requests.Session, term: str, nrc: str) -> List[Dict[str, Any]]:
    """
    Usa la petición 'fetchLinkedSections' para obtener TODAS las secciones ligadas
    de un curso.

    `linkedData` es una lista de grupos, y cada grupo una lista de secciones: un
    curso puede tener varias secciones ligadas alternativas (p. ej. dos grupos de
    laboratorio). Se aplanan todos los grupos y se devuelven todas las secciones
    (dedupe por NRC). Antes se devolvía solo `linkedData[0][0]`, lo que descartaba
    el resto y dejaba esos NRC fuera de la oferta.
    """
    url = "https://bannerssbregistro.utb.edu.co:8443/StudentRegistrationSsb/ssb/searchResults/fetchLinkedSections"
    params = {
        "term": term,
        "courseReferenceNumber": nrc
    }
    rescatados: List[Dict[str, Any]] = []
    try:
        response = session.get(url, params=params, verify=False, timeout=10)
        response.raise_for_status()

        data = response.json()

        linked_data = data.get("linkedData") or []
        vistos: set[str] = set()
        for grupo in linked_data:
            for seccion in grupo:
                crn = seccion.get("courseReferenceNumber")
                if crn and crn not in vistos:
                    vistos.add(crn)
                    rescatados.append(seccion)

    except requests.exceptions.RequestException as e:
        print(f"Error al rescatar NRC {nrc}: {e}")
    except (KeyError, IndexError, TypeError) as e:
        print(f"Error al parsear la respuesta para NRC {nrc}. Estructura inesperada: {e}")
    return rescatados

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
        rescatados = rescatar_cursos_ligados(session, term, nrc)

        if rescatados:
            nrcs_rescatados = [c.get('courseReferenceNumber') for c in rescatados]
            print(f"  -> ¡Éxito! Secciones ligadas de NRC {nrc}: {', '.join(nrcs_rescatados)}")

            # Añadimos cada sección ligada al JSON original si no estaba ya.
            for curso in rescatados:
                crn = curso.get('courseReferenceNumber')
                if crn and crn not in nrcs_existentes:
                    json_data_list.append(curso)
                    nrcs_existentes.add(crn)
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