#WebScraping guia y modulo de SELENIUM
from selenium import webdriver #importar webdriver
from selenium.webdriver.chrome.options import Options #importacion de la clase necesaria para colocar opciones
from selenium.webdriver.common.by import By
"""
Modulos para el main
from startDriver import startChrome as iniciar # Importa este modulo como tal
from selenium.webdriver.common.by import By # Modulo para seleccionar elementos
from selenium.webdriver.support.ui import WebDriverWait # Para esperar elementos
from selenium.webdriver.support import expected_conditions as ec # Para condiciones de selenium
from selenium.common.exceptions import TimeoutException # Excepcion para elementos no cargados

# /// FUNCIONES DE ESPERA (debes primero instanciar wait = WebDriverWait(driver,10))
# Para elementos normales
elemento = wait.until(ec.visibility_of_element_located((By.CSS_SELECTOR, "h1.title_red")))
# Para elementos clikeables
elemento = wait.until(ec.element_to_be_clickable((By.CSS_SELECTOR, "h1.title_red")))

 """
def startChrome(user = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"):
    opt = Options()
    opt.add_argument(f"user-agent={user}") #Define el userAgent
    #opt.add_argument("--headless") #Oculta la ventana del webdriver
    #opt.add_argument("--window-size=900;1080") # Ajusta la ventana a las dimensiones dadas
    opt.add_argument("--start-maximized") # Maximiza la ventada del webdriver
    opt.add_argument("--disable-web-security") #Desabilita la politica del mismo origen o same orgin
    opt.add_argument("--disable-extensions") # Desabilira las extensiones del navegador
    opt.add_argument("--disable-notifications")# Desabilita las notificaciones
    opt.add_argument("--ignore-certificate-errors") # para quitar el anuncion "Su conexion no es privada"
    opt.add_argument("--no-sandbox") # Desabilita el modo sanbox
    opt.add_argument("--log-level=3") # Limpia la salida de la consola
    opt.add_argument("--allow-running-insecure-content") # Desabilita el anuncio de "Contenido no seguro"
    opt.add_argument("--no-default-browser-check") # desabilita el chequeo del navegador predeterminado
    opt.add_argument("--no-first-run") # Desabilita acciones iniciales
    opt.add_argument("--no-proxy-server") # Para no utilizar proxys solo conexiones directas
    opt.add_argument("--disable-blink-features=AutomationControlled") # Evita que selenium sea detectado 
    #Parametros a omitir en el inicio de chrome
    exp_opt = ["enable-automation",# Quita el anuncio de pestaña automatizada
    "ignore-certificate-errors", # Igual que el anterior, sirve dependiendo de la version
    "enable-logging"]  # Evita que webdriver coloque mensajes en consola
    opt.add_experimental_option("excludeSwitches", exp_opt) # Se añade para parametros a omitir
    
    #Parametros que definen las preferencias del chrome
    prefs = {"profile.default_content_setting_values.notification":2, # Notificaciones : 0 = Preguntar; 1 = Permitir; 2 = No permitir
                        "intl.accept_languages": ["es-ES","es"],  # Para definir el lenguaje del navegador
                        "credentials_enable_service": False # No pregutar si quieres guardar las contraseñas
    }
    opt.add_experimental_option("prefs", prefs) #Se añaden las opciones
    driver = webdriver.Chrome(options = opt) # Se inicializa el webdriver
    
    driver.set_window_position(0,0) # Establece la posicion de la ventana
    return driver
    
    """
    APARTADO PARA COOKIES:
    
    // Modulos a importar
    import pickle
    
    // Obtener y guardar las cookies
    
    cookies = driver.get_cookies()
    pickle.dump(cookies, open("Cook Facebook.cookies", "wb"))
    
    // Cargar Cookies
    
    #TRATO DE LOOGUEARME POR MEDIO de COOKIES
    if os.path.exists("Cook Facebook.cookies"): # Verfico si existen
        print("Se han localizado cookies. Se tratara de iniciar sesion con ellas")
        #Ingreso al dominio de facebook
        driver.get("https://www.facebook.com/robots.txt")
        #Cargo las cookies a memoria
        cookies = pickle.load(open("Cook Facebook.cookies", "rb"))
        #Cargo las cookies al driver
        for cookie in cookies:
            driver.add_cookie(cookie)
    
    """
    #---------------------------------------------------------------------------------------------------------
    
    """
    APARTADO PARA BS4 con requests
    
    // Modulo a importar
    
    import requests # requests para peticiones
    from bs4 import BeautifulSoup #  bs4 para la sopa
    
    # Realizar la peticion 
    h = {"user-agent": "Mozilla"}
    res = requests.get(url, headers = h) # headers es opcional
    
    sopa = BeautifulSoup(res.text, "html.parser") # Creamos la sopa dandole el html bruto y el parseador
    ele = sopa.find("h1", class_="title", id="price") # Seleccionamos los elementos objetivos
    objetivo = ele.text # Capturamos lo que nos interesa
    
    
    """
    
    """
        HACER SCROOLL EN SELENIUM
    Se conoce dos formas de hacer scrooll en selenium 
    
    1. Utilizando la tecla especial avanzar pagina (AvPág)
        from selenium.webdriver.common.keys import Keys # Para poder utilizar teclas especiales
        
        elemento = driver.find_element(By.CSS_SELECTOR, "html") # Seleccionamos el html general
        for n in range(30):
            time.sleep(1)
            elemento.send_keys(Keys.PAGE_DOWN) # Presionamos tantas veces quieras para bajar pero con un delay
            
    2. Ejecutando codigo javascript
        
        for n in range(30):
            time.sleep(1)
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);") # Presionamos tantas veces quieras para bajar pero con un delay
    """
    
    """
    PARA DESCARGAR ARCHIVOS 
    
    import wget
    
    wget.download(url, "directorio")
    
    """