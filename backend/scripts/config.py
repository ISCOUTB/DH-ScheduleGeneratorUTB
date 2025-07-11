import os
import psycopg
from dotenv import load_dotenv
from typing import Any

load_dotenv()

DB_CONFIG: dict[str, Any] = {
    'dbname': os.environ['DB_NAME'],
    'user': os.environ['DB_USER'],
    'password': os.environ['DB_PASSWORD'],
    'host': os.environ['DB_HOST'],
    'port': int(os.environ['DB_PORT'])
}

def get_connection():
    return psycopg.connect(**DB_CONFIG)
