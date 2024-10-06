# lib/scrapping.py

from startDriver import startChrome as iniciar  # Importa este modulo como tal
from selenium.webdriver.common.by import By  # Modulo para seleccionar elementos
from selenium.webdriver.support.ui import WebDriverWait  # Para esperar elementos
from selenium.webdriver.support import expected_conditions as ec  # Para condiciones de selenium
from selenium.common.exceptions import TimeoutException  # Excepcion para elementos no cargados
import os  # Para verificar si ya existen archivos
from credenciales import pase as pase
import pickle
from selenium.webdriver.common.keys import Keys  # Para poder utilizar teclas especiales
from selenium.webdriver.support.ui import Select
from datetime import date, datetime
import logging

# CONFIGURACIÓN DE LOGGING
logging.basicConfig(
    filename='scraping.log',
    level=logging.INFO,
    format='%(asctime)s:%(levelname)s:%(message)s'
)

# Variables globales
subjects = []

# FUNCION PARA LIMPIAR PANTALLA
def limpiar():
    os.system("cls" if os.name == "nt" else "clear")

def format_as_dart(subjects):
    """Formatea los datos del scraping como código Dart."""
    dart_code = ""
    for subject in subjects:
        dart_code += "  Subject(\n"
        dart_code += f"    code: '{subject['code']}',\n"
        dart_code += f"    name: '{subject['name']}',\n"
        dart_code += f"    credits: {subject['credits']},\n"
        dart_code += "    classOptions: [\n"
        for option in subject['classOptions']:
            dart_code += "      ClassOption(\n"
            dart_code += f"        subjectName: '{option['subjectName']}',\n"
            dart_code += f"        type: '{option['type']}',\n"
            dart_code += f"        credits: {option['credits']},\n"
            dart_code += f"        professor: '{option['professor']}',\n"
            dart_code += f"        nrc: '{option['nrc']}',\n"
            dart_code += f"        groupId: {option['groupId']},\n"
            dart_code += "        schedules: [\n"
            for schedule in option['schedules']:
                dart_code += f"          Schedule(day: '{schedule['day']}', time: '{schedule['time']}'),\n"
            dart_code += "        ],\n"
            dart_code += "      ),\n"
        dart_code += "    ],\n"
        dart_code += "  ),\n"
    return dart_code

# FUNCION PARA SCRAPEAR
def scrape():
    url = "https://bannerssbregistro.utb.edu.co:8443/StudentRegistrationSsb/ssb/classSearch/classSearch"

    # Día Actual
    today = date.today()
    # Fecha actual
    now = datetime.now()

    # Instancio el driver
    driver = iniciar()
    # Establezco el wait
    wait = WebDriverWait(driver, 100)

    # Llego al navegador a la página de banner
    driver.get(url)

    # Ruta y nombre del archivo de salida
    output_dir = r"C:\Users\gabri\OneDrive\Documentos\Proyectos\schedule_generator\DH-ScheduleGeneratorUTB\lib\data\RegistrosUTB\output"
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    filename = f"BD_REGISTROS_BANNER_{today}_HMS_{now.hour}.{now.minute}.{now.second}.txt"
    filepath = os.path.join(output_dir, filename)

    today = date.today()
    now = datetime.now()
    file_name = f"subjects_data_{today}_HMS_{now.hour}.{now.minute}.{now.second}.dart"
    ruta_directorio = r"C:\Users\gabri\OneDrive\Documentos\Proyectos\schedule_generator\DH-ScheduleGeneratorUTB\lib\data\RegistrosUTB\output"
    if not os.path.exists(ruta_directorio):
        os.makedirs(ruta_directorio)

    try:
        # Abrir archivo usando 'with' para manejo seguro
        with open(filepath, "a", encoding="utf-8") as arch, open(os.path.join(ruta_directorio, file_name), 'w', encoding="utf-8") as file:
            logging.info("Inicio del scraping")
            file.write("import '../../../models/class_option.dart';\nimport '../../../models/schedule.dart';\nimport '../../../models/subject.dart';\nList<Subject> subjects = [\n")  # Iniciar el archivo Dart

            # Click en 'Examinar clases'
            ele = wait.until(ec.element_to_be_clickable((By.XPATH, "//span[text()='Examinar clases']")))
            ele.click()
            logging.info("Hice click en 'Examinar clases'")

            # Seleccionar periodo
            ele = wait.until(ec.element_to_be_clickable((By.ID, "select2-chosen-1")))
            ele.click()
            logging.info("Hice click en seleccionar periodo")

            ele = wait.until(ec.element_to_be_clickable((By.ID, "202420")))
            ele.click()
            logging.info("Seleccioné el periodo 2024-1")

            ele = wait.until(ec.element_to_be_clickable((By.ID, "term-go")))
            ele.click()
            logging.info("Hice click en 'Ir'")

            # Hacer click en buscar
            ele = wait.until(ec.element_to_be_clickable((By.ID, "search-go")))
            ele.click()
            logging.info("Hice click en 'Buscar'")

            # Seleccionar 50 registros por página
            ele = wait.until(ec.visibility_of_element_located((By.CSS_SELECTOR, "select.page-size-select")))
            seleccionador = Select(ele)
            seleccionador.select_by_value("50")
            logging.info("Seleccioné 50 registros por página")
            # Obtener el número de páginas totales
            PAGINAS = int(wait.until(ec.visibility_of_element_located((By.CSS_SELECTOR, "span.total-pages"))).text)
            logging.info(f"Número de páginas a procesar: {PAGINAS}")
            
            contaPer = 0
            for i in range(PAGINAS):
                # Esperar a que aparezca el primer elemento
                parada = wait.until(ec.element_to_be_clickable((By.CSS_SELECTOR, "tr[data-id]")))

                # Obtener todos los registros de la página
                perlas = driver.find_elements(By.CSS_SELECTOR, "tr[data-id]")
                logging.info(f"Procesando página {i + 1} de {PAGINAS}, cantidad de registros: {len(perlas)}")

                for per in perlas:
                    contaPer += 1
                    try:
                        # Extraer datos
                        nombre = per.find_element(By.CSS_SELECTOR, 'a').text
                        teo = per.find_element(By.CSS_SELECTOR, 'span').text
                        escuela = per.find_element(By.CSS_SELECTOR, "td[data-property='subjectDescription']").get_attribute("title")
                        numeroCurso = per.find_element(By.CSS_SELECTOR, "td[data-property='courseNumber']").text
                        seccion = per.find_element(By.CSS_SELECTOR, "td[data-property='sequenceNumber']").text
                        creditos = per.find_element(By.CSS_SELECTOR, "td[data-property='creditHours']").text
                        if not creditos:
                            creditos = 0
                        else:
                            creditos = int(creditos)
                        nrc = per.find_element(By.CSS_SELECTOR, "td[data-property='courseReferenceNumber']").text
                        instructor = per.find_element(By.CSS_SELECTOR, "td[data-property='instructor']").text.split("(")[0].strip() if per.find_element(By.CSS_SELECTOR, "td[data-property='instructor']").text else "NA"

                        # Obtener horario
                        strhorario = per.find_element(By.CSS_SELECTOR, "td[data-property='meetingTime']").get_attribute("title").replace("LunMarMiéJueVieSábDom", " ").replace("2024", "Tipo").split("Tipo")
                        horario = [horastr.strip().strip("-") for horastr in strhorario if horastr.strip()]
                        campus = per.find_element(By.CSS_SELECTOR, "td[data-property='campus']").text 
                        alumOpen = per.find_element(By.CSS_SELECTOR, "td[data-property='status']").text.split("de")[0].strip()

                        schedule_list = []
                        for horastr in horario:
                            partes = horastr.split(" ", 1)  # Dividimos el string en dos partes: día y horario
                            if len(partes) == 2:
                                day = partes[0].strip()  # El día es la primera parte
                                tite = partes[1].strip()
                                schedule_list.append({'day': day, 'time': tite})
                        
                        # Formatear y escribir cada materia en el archivo Dart
                        dart_code = format_as_dart([{
                            'code': numeroCurso,
                            'name': nombre,
                            'credits': creditos,
                            'classOptions': [{
                                'subjectName': nombre,
                                'type': teo,
                                'credits': creditos,
                                'schedules': schedule_list,
                                'professor': instructor,
                                'nrc': nrc,
                                'groupId': contaPer,
                            }]
                        }])
                        file.write(dart_code)

                        # Guardar el registro en el archivo de texto
                        registro = f"{nombre};{teo};{escuela};{numeroCurso};{seccion};{creditos};{nrc};{instructor};{'/'.join(horario)};{campus};{alumOpen};"
                        logging.info(f"Registro {contaPer}: {registro}")
                        print(registro)
                        arch.write(registro + "\n")

                    except Exception as e:
                        logging.error(f"Error al procesar un registro: {e}")
                        print(f"Error al procesar un registro: {e}")

                # Navegar a la siguiente página
                ele = wait.until(ec.element_to_be_clickable((By.CSS_SELECTOR, "button[title='Siguiente']")))
                ele.click()
                logging.info("Navegué a la siguiente página")
                limpiar()

            # Terminar el archivo Dart
            file.write("];\n")
            logging.info("Código Dart generado correctamente")

    except TimeoutException as te:
        logging.error(f"TimeoutException: {te}")
        print("Se produjo un timeout al intentar encontrar un elemento.")
    except Exception as e:
        logging.error(f"Exception: {e}")
        print("Se produjo algún error:", e)
    finally:
        try:
            driver.close()
        except Exception:
            pass
        try:
            arch.close()
        except Exception:
            pass
        logging.info("Scraping finalizado")


if __name__ == "__main__":
    scrape()
