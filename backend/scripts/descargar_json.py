import requests
import json


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
        "term": "202510",  # PRIMER PERIODO 2025 PREGRADO
        "studyPath": "",
        "studyPathText": "",
        "startDatepicker": "",
        "endDatepicker": "",
    }
    session.post(search_url, data=payload, headers=headers, verify=False)

    # Paginación
    page_offset = 0
    page_max_size = 500
    all_results = []

    while True:
        search_results_url = f"{base_url}/searchResults/searchResults?txt_term=202510&startDatepicker=&endDatepicker=&pageOffset={page_offset}&pageMaxSize={page_max_size}&sortColumn=subjectDescription&sortDirection=asc"
        response = session.get(search_results_url, headers=headers, verify=False)

        if response.status_code != 200:
            print(f"Error en offset {page_offset}: {response.status_code}")
            break

        page_data = response.json().get("data", [])
        if not page_data:
            break

        print(f"Obtenidos {len(page_data)} registros desde offset {page_offset}")
        all_results.extend(page_data)
        page_offset += page_max_size

    # Guardar todos los resultados en un archivo JSON
    with open("search_results_complete.json", "w", encoding="utf-8") as json_file:
        json.dump({"data": all_results}, json_file, indent=4, ensure_ascii=False)

    print(f"Total cursos guardados: {len(all_results)} en 'search_results_complete.json'")
