import requests
import json
import os
from typing import Any
from config import CURRENT_TERM

def descargar_json():
# Mantener la misma sesión activa
    session = requests.Session()

    # URL base del sistema
    base_url = "https://bannerssbregistro.utb.edu.co:8443/StudentRegistrationSsb/ssb"

    # Headers simulando una petición real del navegador
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36",
        "Accept": "application/json, text/javascript, */*; q=0.01",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-Requested-With": "XMLHttpRequest",
        "Referer": f"{base_url}/term/termSelection?mode=search",
    }

    # Obtener cookies iniciales accediendo a la selección de período
    session.get(f"{base_url}/term/termSelection?mode=search", headers=headers, verify=False)

    # Simular clic en "Continuar" enviando los datos correctos en `Form Data`
    search_url = f"{base_url}/term/search?mode=search"
    payload = {
        "term": CURRENT_TERM,  # Período académico desde .env
        "studyPath": "",
        "studyPathText": "",
        "startDatepicker": "",
        "endDatepicker": "",
    }
    session.post(search_url, data=payload, headers=headers, verify=False)

    # Paginación
    page_offset = 0
    page_max_size = 500
    all_results: list[dict[str, Any]] = []

    while True:
        search_results_url = f"{base_url}/searchResults/searchResults?txt_term={CURRENT_TERM}&startDatepicker=&endDatepicker=&pageOffset={page_offset}&pageMaxSize={page_max_size}&sortColumn=subjectDescription&sortDirection=asc"
        response = session.get(search_results_url, headers=headers, verify=False)

        # Un error HTTP (ej. 502 de Banner) significa descarga INCOMPLETA: se
        # aborta lanzando excepción para NO sobrescribir el cache válido ni dejar
        # que el ETL limpie la base con datos parciales/vacíos.
        if response.status_code != 200:
            raise RuntimeError(
                f"Banner devolvió {response.status_code} en offset {page_offset}. "
                "Descarga abortada (datos incompletos); no se sobrescribe el JSON."
            )

        page_data = response.json().get("data", [])
        if not page_data:
            break  # Fin normal de la paginación (200 sin más resultados).

        print(f"Obtenidos {len(page_data)} registros desde offset {page_offset}")


        all_results.extend(page_data)
        page_offset += page_max_size

    # Si no se obtuvo ningún curso, abortar sin escribir: un JSON vacío haría que
    # el ETL borre la oferta académica. Probable caída/timeout de Banner.
    if not all_results:
        raise RuntimeError(
            "Banner no devolvió cursos (0 resultados). Descarga abortada para no "
            "sobrescribir datos válidos."
        )

    # Guardar todos los resultados en un archivo JSON (solo si hubo resultados).
    EXPORT_DIR = os.path.join(os.path.dirname(__file__), "data_scrapped")
    os.makedirs(EXPORT_DIR, exist_ok=True)
    with open(f"{EXPORT_DIR}/search_results_complete.json", "w", encoding="utf-8") as json_file:
        json.dump({"data": all_results}, json_file, indent=4, ensure_ascii=False)

    print(f"Total cursos guardados: {len(all_results)} en 'search_results_complete.json'")
