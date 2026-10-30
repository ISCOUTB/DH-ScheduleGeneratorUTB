"""
Fixture compartida de las pruebas con base de datos de la planificación.

`bd` da una conexión (autocommit) a un PostgreSQL de prueba en
`DH_TEST_DATABASE_URL`, con el esquema `public` recién creado por init.sql.
Esa base se borra entera en cada prueba: nunca la de un ambiente real. Sin la
variable, las pruebas que la piden se omiten.
"""
import os
from pathlib import Path

import pytest

RAIZ = Path(__file__).resolve().parent.parent
URL_PRUEBA = os.getenv("DH_TEST_DATABASE_URL")


@pytest.fixture
def bd():
    if not URL_PRUEBA:
        pytest.skip("sin DH_TEST_DATABASE_URL")
    psycopg = pytest.importorskip("psycopg")
    c = psycopg.connect(URL_PRUEBA, autocommit=True)
    c.execute("DROP SCHEMA public CASCADE")
    # Como en una base nueva (PostgreSQL 15+): init.sql da las tablas a
    # pg_database_owner, que necesita el esquema para revisar las llaves.
    c.execute("CREATE SCHEMA public AUTHORIZATION pg_database_owner")
    c.execute((RAIZ / "backend" / "init.sql").read_text(encoding="utf-8"))
    c.execute("SET search_path TO public")
    yield c
    c.close()
