# config.py
import os
import psycopg
from dotenv import load_dotenv

# Define la ruta base del proyecto (la carpeta 'backend')
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Carga el .env.local para desarrollo si existe
load_dotenv(dotenv_path=os.path.join(BASE_DIR, '.env.local'))

# Si DATABASE_URL no se cargó, carga el .env principal (para Docker)
if not os.getenv('DATABASE_URL'):
    print("Cargando configuración desde .env...")
    load_dotenv(dotenv_path=os.path.join(BASE_DIR, '.env'))

# Lee la URL de conexión completa directamente desde el entorno.
DATABASE_URL = os.getenv('DATABASE_URL')

def get_connection() -> psycopg.Connection:
    """Crea y devuelve una nueva conexión a la base de datos."""
    if not DATABASE_URL:
        raise ValueError("DATABASE_URL no está definida. Asegúrate de que backend/.env o backend/.env.local exista y esté configurado.")
    
    print(f"Intentando conectar a: {DATABASE_URL.split('@')[-1]}") # Imprime a dónde se conecta para depurar
    return psycopg.connect (DATABASE_URL)
