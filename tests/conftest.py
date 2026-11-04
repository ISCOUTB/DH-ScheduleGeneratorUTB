"""
Fixtures compartidas de las pruebas con base de datos de la planificación.

`bd` da una conexión (autocommit) a un PostgreSQL de prueba en
`DH_TEST_DATABASE_URL`, con el esquema `public` recién creado por init.sql.
Esa base se borra entera en cada prueba: nunca la de un ambiente real. Sin la
variable, las pruebas que la piden se omiten.

`api` da un cliente de la API sobre esa base, con la lista `LISTA_PLANIFICACION`
cargada y dos usuarios; la sesión es la del usuario 1 hasta `entrar_como(n)`.
"""
import os
import sys
from pathlib import Path

import pytest

RAIZ = Path(__file__).resolve().parent.parent
URL_PRUEBA = os.getenv("DH_TEST_DATABASE_URL")

LISTA_PLANIFICACION = {
    "term": "202710",
    "termLabel": "2027-1",
    "listVersion": "v-prueba",
    "subjects": [
        {"code": "CBAS-M03A", "name": "Cálculo Integral", "credits": 4, "subject": "CBAS",
         "levels": ["UG"], "programs": ["Ingeniería Civil"]},
        {"code": "CBAS-M01B", "name": "Cálculo Univariable", "credits": 3, "subject": "CBAS"},
        {"code": "IIND-P09A", "name": "Proyecto de Grado", "credits": 15, "subject": "IIND"},
        {"code": "CHUL-I03A", "name": "Inglés III", "credits": 2, "equivalentCodes": ["RULE-I03B"]},
        {"code": "RULE-I03B", "name": "Inglés III", "credits": 2, "equivalentCodes": ["CHUL-I03A"]},
        {"code": "CBAS-F03A", "name": "Física Calor y Ondas", "credits": None, "nameTruncated": True},
    ],
}


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


@pytest.fixture
def api(bd, monkeypatch):
    """(cliente, bd, entrar_como, ids de los dos usuarios)."""
    for ruta in (RAIZ / "backend", RAIZ / "backend" / "scripts"):
        if str(ruta) not in sys.path:
            sys.path.insert(0, str(ruta))
    # auth/routes.py lee el tenant al importarse.
    os.environ.setdefault("AZURE_TENANT_ID", "tenant-utb")
    from fastapi.testclient import TestClient

    from app import main
    from app.auth import routes as auth_routes
    from app.db import repository
    import cargar_lista_planificacion as carga

    monkeypatch.setattr(repository, "DATABASE_URL", URL_PRUEBA)
    carga.cargar(bd, carga.leer_lista(LISTA_PLANIFICACION))
    ids = [
        bd.execute(
            "INSERT INTO usuario (entra_id, email) VALUES (%s, %s) RETURNING id",
            (f"oid-{n}", f"e{n}@utb.edu.co"),
        ).fetchone()[0]
        for n in (1, 2)
    ]
    sesion = {"usuario": {"id": "oid-1", "email": "e1@utb.edu.co", "db_user_id": ids[0]}}
    main.app.dependency_overrides[auth_routes.require_user] = lambda: sesion["usuario"]
    client = TestClient(main.app)

    def entrar_como(n):
        sesion["usuario"] = {"id": f"oid-{n}", "email": f"e{n}@utb.edu.co", "db_user_id": ids[n - 1]}

    yield client, bd, entrar_como, ids
    main.app.dependency_overrides.pop(auth_routes.require_user, None)
