import requests
from bs4 import BeautifulSoup
import json

def scrape_subjects():
    url = 'https://bannerssbregistro.utb.edu.co:8443/StudentRegistrationSsb/ssb/classSearch/classSearch'
    response = requests.get(url)

    if response.status_code == 200:
        soup = BeautifulSoup(response.text, 'html.parser')
        # Ajusta el selector según la estructura real de la página
        rows = soup.select('table tbody tr')  

        subjects = []

        for row in rows:
            cells = row.find_all('td')
            if len(cells) >= 6:
                code = cells[0].get_text(strip=True)
                name = cells[1].get_text(strip=True)
                nrc = cells[2].get_text(strip=True)
                credits = int(cells[3].get_text(strip=True))
                itinerary = cells[4].get_text(strip=True)
                professor = cells[5].get_text(strip=True)

                subjects.append({
                    'code': code,
                    'name': name,
                    'nrc': nrc,
                    'credits': credits,
                    'itinerary': itinerary,
                    'professor': professor
                })

        # Guardar los datos en un archivo JSON
        with open('assets/subjects.json', 'w', encoding='utf-8') as f:
            json.dump(subjects, f, ensure_ascii=False, indent=4)
    else:
        print(f'Failed to retrieve data. Status code: {response.status_code}')

if __name__ == '__main__':
    scrape_subjects()
