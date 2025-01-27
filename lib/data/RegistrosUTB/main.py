from startDriver import startChrome as iniciar  # Importa este módulo como tal
from selenium.webdriver.common.by import By  # Módulo para seleccionar elementos
from selenium.webdriver.support.ui import WebDriverWait  # Para esperar elementos
from selenium.webdriver.support import expected_conditions as ec  # Para condiciones de Selenium
from selenium.common.exceptions import TimeoutException  # Excepción para elementos no cargados
import os  # Para verificar si ya existen archivos
import time
from selenium.webdriver.support.ui import Select
from datetime import date, datetime

# FUNCIÓN PARA LIMPIAR PANTALLA
def limpiar():
    os.system("cls" if os.name == "nt" else "clear")

def formatear_cadena(cadena):
    """Convierte una cadena a formato título, preservando tildes y caracteres especiales."""
    excepciones = {
        'TEORICO': 'Teórico',
        'LABORATORIO': 'Laboratorio',
        'PRACTICA': 'Práctica',
        'TALLER': 'Taller',
        'SABADO': 'Sábado',
        'DOMINGO': 'Domingo',
    }
    cadena = cadena.strip()
    if cadena.upper() in excepciones:
        return excepciones[cadena.upper()]
    else:
        return cadena.capitalize()

def format_as_dart(subjects):
    """Formatea los datos del scraping como código Dart."""
    dart_code = ""
    for subject in subjects.values():
        dart_code += "  Subject(\n"
        dart_code += f"    code: '{subject['code']}',\n"
        dart_code += f"    name: '{subject['name']}',\n"
        dart_code += f"    credits: {subject['credits']},\n"
        dart_code += "    classOptions: [\n"
        for option in subject['classOptions']:
            dart_code += "      ClassOption(\n"
            dart_code += f"        subjectCode: '{option['code']}',\n"
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

if __name__ == "__main__":
    url = "https://bannerssbregistro.utb.edu.co:8443/StudentRegistrationSsb/ssb/classSearch/classSearch"

    # Fecha actual
    today = date.today()
    now = datetime.now()

    # Instancio el driver
    driver = iniciar()
    # Establezco el wait
    wait = WebDriverWait(driver, 100)
    # Llevo al navegador a la página de banner
    driver.get(url)

    # Creación del archivo txt
    output_dir = r"C:\Users\gabri\Documentos\GitHub\DH-ScheduleGeneratorUTB\lib\data\RegistrosUTB\output_DB"
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    filename = f"BD_REGISTROS_BANNER_{today}_HMS_{now.hour}.{now.minute}.{now.second}.txt"
    filepath = os.path.join(output_dir, filename)

    # Creación del archivo .dart
    file_name = f"subjects_data_{today}_HMS_{now.hour}.{now.minute}.{now.second}.dart"
    ruta_directorio = output_dir  # Usamos la misma ruta
    if not os.path.exists(ruta_directorio):
        os.makedirs(ruta_directorio)

    subjects_dict = {}  # Diccionario para almacenar los subjects

    try:
        # Abrir archivos
        arch_txt = open(filepath, "a", encoding="utf-8")
        file_dart = open(os.path.join(ruta_directorio, file_name), 'w', encoding="utf-8")
        # Iniciar el archivo Dart
        file_dart.write("import '../../../models/class_option.dart';\n")
        file_dart.write("import '../../../models/schedule.dart';\n")
        file_dart.write("import '../../../models/subject.dart';\n")
        file_dart.write("List<Subject> subjects = [\n")  # Iniciar la lista de subjects

        # Navegación en la página
        ele = wait.until(ec.element_to_be_clickable((By.XPATH, "//span[text()='Examinar clases']")))
        ele.click()  # Hago click en examinar clases
        ele = wait.until(ec.element_to_be_clickable((By.ID, "select2-chosen-1")))
        ele.click()  # Hago click en seleccionar periodo
        ele = wait.until(ec.element_to_be_clickable((By.ID, "202510")))
        ele.click()  # Selecciono el periodo correspondiente 2024-1
        ele = wait.until(ec.element_to_be_clickable((By.ID, "term-go")))
        ele.click()  # Hago click en "ir"

        ele = wait.until(ec.element_to_be_clickable((By.ID, "search-go")))
        ele.click()  # Hago click en buscar para buscar todos los registros

        # Selecciono que se muestren 50 registros por página
        ele = wait.until(ec.visibility_of_element_located((By.CSS_SELECTOR, "select.page-size-select")))
        seleccionador = Select(ele)
        seleccionador.select_by_value("50")
        time.sleep(15)  # Esperar a que cargue la página

        # Obtengo el número de páginas totales
        PAGINAS = int(wait.until(ec.visibility_of_element_located((By.CSS_SELECTOR, "span.total-pages"))).text)
        contaPer = 0

        # Inicializar el contador de groupIds y el diccionario de NRCs ligados
        group_id_counter = 1
        ligados_nrc_to_groupid = {}

        for page_index in range(PAGINAS):  # Recorro las páginas
            # Espero a que aparezca el primer elemento
            parada = wait.until(ec.element_to_be_clickable((By.CSS_SELECTOR, "tr[data-id]")))
            time.sleep(5)
            # Obtengo todos los registros de la página
            perlas = driver.find_elements(By.CSS_SELECTOR, "tr[data-id]")
            print("------------------------------------------------")
            print(f"Página {page_index + 1} de {PAGINAS}")  # Poner pag 1 de N
            print(f"Cantidad de Recursos en la página: {len(perlas)}")
            print("------------------------------------------------")
            print()
            # Recorro todas las perlas
            idx = 0

            while idx < len(perlas):
                per = perlas[idx]
                contaPer += 1
                print()

                # Extracción de datos
                nombre = per.find_element(By.CSS_SELECTOR, 'a').text
                nombre = formatear_cadena(nombre.title())

                teo = per.find_element(By.CSS_SELECTOR, 'span').text
                teo = formatear_cadena(teo)

                escuela = per.find_element(By.CSS_SELECTOR, "td[data-property='subjectDescription']").get_attribute("title")
                numeroCurso = per.find_element(By.CSS_SELECTOR, "td[data-property='courseNumber']").text
                seccion = per.find_element(By.CSS_SELECTOR, "td[data-property='sequenceNumber']").text
                creditos = per.find_element(By.CSS_SELECTOR, "td[data-property='creditHours']").text
                if creditos == '0':
                    per.find_element(By.CSS_SELECTOR, 'a').click()
                    time.sleep(5)
                    try:
                        # Espera hasta que el contenedor esté visible
                        ele = wait.until(ec.visibility_of_element_located((By.CSS_SELECTOR, '#classDetailsContentDetailsDiv')))
                        # Obtiene todo el texto del div
                        full_text = ele.text.strip()
                        # Imprime el texto completo para depurar
                        print(full_text)
                        # Busca las horas de crédito en el texto completo
                        if "Horas crédito:" in full_text:
                            for line in full_text.splitlines():
                                if "Horas crédito:" in line:
                                    creditos = line.split(":")[1].strip()
                                    if not creditos:
                                        creditos = '0'
                                    break
                        else:
                            creditos = '4'  # Valor por defecto si no se encuentra la línea

                    except TimeoutException:
                        creditos = '4'  # Valor por defecto si se agota el tiempo de espera

                    # Cierra la ventana
                    try:
                        omg = wait.until(ec.element_to_be_clickable((By.XPATH, "//span[text()='close']")))
                        omg.click()
                    except TimeoutException:
                        print("El botón de cerrar no fue encontrado o no es clickable.")
                    print(creditos)

                nrc = per.find_element(By.CSS_SELECTOR, "td[data-property='courseReferenceNumber']").text

                # ====== NUEVO BLOQUE PARA OMITIR VARIOS NRCs PROBLEMÁTICOS ======
                nrcs_a_omitir = {"2604", "2672", "2594", "2595", "2596", "2597"}
                if nrc in nrcs_a_omitir:
                    print(f"Omitimos la clase con NRC {nrc} por error en la página.")
                    idx += 1
                    continue
                # ===============================================================

                instructor = per.find_element(By.CSS_SELECTOR, "td[data-property='instructor']").text
                if instructor == "":
                    instructor = "NA"
                else:
                    instructor = instructor.split("(")[0].strip().title()

                # Guardo el HORARIO usando tu método original
                strhorario = per.find_element(By.CSS_SELECTOR, "td[data-property='meetingTime']").get_attribute("title")
                strhorario = strhorario.replace("LunMarMiéJueVieSábDom", " ")
                strhorario = strhorario.replace("2025", "Tipo")
                strhorario = strhorario.split("Tipo")
                horario = []
                for i in range(0, len(strhorario), 3):
                    if strhorario[i].strip():
                        horastr = strhorario[i].strip()
                        if "Ninguno" in horastr:
                            horastr = horastr.strip("-").strip()
                        horario.append(horastr)
                sumHorario = ""
                for i in range(len(horario)):
                    if (i + 1) != len(horario):
                        sumHorario += horario[i] + "/"
                    else:
                        sumHorario += horario[i]

                # Convertir horario a schedule_list
                schedule_list = []
                for horastr in horario:
                    partes = horastr.split(" ", 1)  # Dividimos el string en dos partes: día y horario
                    if len(partes) == 2:
                        day = formatear_cadena(partes[0].title())  # El día es la primera parte
                        tite = partes[1].strip()
                        schedule_list.append({'day': day, 'time': tite})

                campus = per.find_element(By.CSS_SELECTOR, "td[data-property='campus']").text
                alumOpen = per.find_element(By.CSS_SELECTOR, "td[data-property='status']").text.split("de")[0].strip()

                # Guardo los cursos ligados
                strlig = per.find_element(By.CSS_SELECTOR, "td[data-property='add']").text

                # Crear una clave única para agrupar materias
                subject_key = f"{numeroCurso}-{nombre}"

                # Si la materia ya existe en el diccionario subjects, la actualizamos
                if subject_key not in subjects_dict:
                    subjects_dict[subject_key] = {
                        'code': numeroCurso,
                        'name': nombre,
                        'credits': creditos,
                        'classOptions': []
                    }
                    # Reiniciar groupId y NRCs ligados para nueva materia
                    group_id_counter = 1
                    ligados_nrc_to_groupid = {}

                # Verificar si el NRC actual está en los NRCs ligados
                if nrc in ligados_nrc_to_groupid:
                    current_groupId = ligados_nrc_to_groupid[nrc]
                else:
                    # Asignar un nuevo groupId
                    current_groupId = group_id_counter
                    group_id_counter += 1

                if strlig == "Ver ligados":
                    # Hay clases ligadas
                    ligados = []
                    per.find_element(By.CSS_SELECTOR, 'a').click()
                    ele = wait.until(ec.element_to_be_clickable((By.XPATH, "//a[text()='Secciones ligadas']")))
                    ele.click()
                    ele = wait.until(ec.visibility_of_element_located((By.XPATH, "//div[text()='Secciones ligadas']")))
                    cursosAdds = driver.find_elements(By.CSS_SELECTOR, "tbody")
                    for i in range(1, len(cursosAdds), 1):
                        ligados_nrc = cursosAdds[i].text[-4:]
                        ligados.append(ligados_nrc)
                    ele = wait.until(ec.element_to_be_clickable((By.XPATH, "//span[text()='close']")))
                    ele.click()

                    sumLigados = "/".join(ligados)

                    # Mapear el NRC de la clase principal y los ligados al current_groupId
                    ligados_nrc_to_groupid[nrc] = current_groupId
                    for ligado_nrc in ligados:
                        ligados_nrc_to_groupid[ligado_nrc] = current_groupId

                    # Agregar la clase actual como ClassOption
                    class_option = {
                        'subjectName': nombre,
                        'code': numeroCurso,
                        'type': teo,
                        'credits': creditos,
                        'schedules': schedule_list,
                        'professor': instructor,
                        'nrc': nrc,
                        'groupId': current_groupId,
                    }
                    subjects_dict[subject_key]['classOptions'].append(class_option)

                    # Escribir en el archivo de texto
                    str_line = f"{nombre};{teo};{escuela};{numeroCurso};{seccion};{creditos};{nrc};{instructor};{sumHorario};{campus};{alumOpen};{sumLigados}"
                    print(str_line)
                    arch_txt.write(str_line + "\n")

                    idx += 1  # Avanzar al siguiente índice

                else:
                    sumLigados = "NA"

                    # Agregar la clase actual como ClassOption
                    class_option = {
                        'subjectName': nombre,
                        'code': numeroCurso,
                        'type': teo,
                        'credits': creditos,
                        'schedules': schedule_list,
                        'professor': instructor,
                        'nrc': nrc,
                        'groupId': current_groupId,
                    }
                    subjects_dict[subject_key]['classOptions'].append(class_option)

                    # Escribir en el archivo de texto
                    str_line = f"{nombre};{teo};{escuela};{numeroCurso};{seccion};{creditos};{nrc};{instructor};{sumHorario};{campus};{alumOpen};{sumLigados}"
                    print(str_line)
                    arch_txt.write(str_line + "\n")

                    idx += 1  # Avanzar al siguiente índice

            # Navegar a la siguiente página
            ele = wait.until(ec.element_to_be_clickable((By.CSS_SELECTOR, "button[title='Siguiente']")))
            ele.click()
            time.sleep(5)  # Esperar para garantizar que cargue la página siguiente
            limpiar()

    except Exception as e:
        print(f"Se produjo un error durante el scraping: {e}")
    finally:
        # Cerrar archivos y driver
        # Al finalizar, formatear y escribir todos los subjects en el archivo Dart
        dart_code = format_as_dart(subjects_dict)
        file_dart.write(dart_code)
        file_dart.write("];\n")  # Cerrar la lista de subjects
        arch_txt.close()
        file_dart.close()
        driver.close()
        print("Scraping finalizado.")

    input("Pausa...")
exit(0)