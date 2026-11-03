"""
Rutas de la planificación del período siguiente (`/api/planning`, HU #380 de
la app), con la base de prueba (`DH_TEST_DATABASE_URL`):

- `GET /current`: el período abierto y dentro de su ventana; 404 si no hay;
- `GET /{term}/subjects`: la lista activa con sus equivalentes activos; 404
  si el período no existe o es un borrador;
- `GET` y `PUT /{term}/plan`: piden sesión (401 sin ella); el plan es de quien
  tiene la sesión, nunca de un id que venga en el cuerpo; el `PUT` reemplaza el
  plan en el orden dado y revisa lo mismo que la app: período abierto (409),
  sin repetidos (400), materias de la lista (422; una que salió de la lista se
  conserva si ya estaba en el plan) y máximo 20 créditos (422);
- las fechas salen en ISO 8601 con desfase horario.
"""
import os
from datetime import datetime, timedelta, timezone

import pytest

from conftest import RAIZ, URL_PRUEBA

import sys

sys.path.insert(0, str(RAIZ / "backend"))
sys.path.insert(0, str(RAIZ / "backend" / "scripts"))
# auth/routes.py lee el tenant al importarse.
os.environ.setdefault("AZURE_TENANT_ID", "tenant-utb")

from fastapi.testclient import TestClient  # noqa: E402

from app import main  # noqa: E402
from app.auth import routes as auth_routes  # noqa: E402
from app.db import repository  # noqa: E402
import cargar_lista_planificacion as carga  # noqa: E402

LISTA = {
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
def api(bd, monkeypatch):
    monkeypatch.setattr(repository, "DATABASE_URL", URL_PRUEBA)
    carga.cargar(bd, carga.leer_lista(LISTA))
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


def _codigos(respuesta):
    return [m["code"] for m in respuesta.json()["subjects"]]


# --- Período y lista (sin sesión) --------------------------------------------


def test_periodo_actual(api):
    client, bd, _, _ = api
    r = client.get("/api/planning/current")
    assert r.status_code == 200
    assert r.json() == {"term": "202710", "label": "2027-1", "listVersion": "v-prueba", "opensAt": None, "closesAt": None}

    ayer = datetime.now(timezone.utc) - timedelta(days=1)
    bd.execute("UPDATE periodo_planificacion SET cierra = %s", (ayer,))
    assert client.get("/api/planning/current").status_code == 404
    bd.execute("UPDATE periodo_planificacion SET cierra = NULL, abre = %s", (ayer + timedelta(days=2),))
    assert client.get("/api/planning/current").status_code == 404
    bd.execute("UPDATE periodo_planificacion SET abre = NULL, estado = 'cerrado'")
    assert client.get("/api/planning/current").status_code == 404


def test_lista_del_periodo(api):
    client, bd, _, _ = api
    bd.execute("UPDATE materia_planificable SET activa = FALSE WHERE codigo = 'CBAS-M01B'")
    r = client.get("/api/planning/202710/subjects")
    assert r.status_code == 200
    cuerpo = r.json()
    assert cuerpo["term"] == "202710" and cuerpo["listVersion"] == "v-prueba"
    por_codigo = {m["code"]: m for m in cuerpo["subjects"]}
    assert "CBAS-M01B" not in por_codigo  # inactiva
    assert por_codigo["RULE-I03B"]["equivalentCodes"] == ["CHUL-I03A"]
    assert por_codigo["CBAS-M03A"] == {
        "code": "CBAS-M03A", "name": "Cálculo Integral", "credits": 4.0, "area": "CBAS",
        "levels": ["UG"], "programs": ["Ingeniería Civil"], "nameTruncated": False, "equivalentCodes": [],
    }
    assert por_codigo["CBAS-F03A"]["credits"] is None
    assert por_codigo["CBAS-F03A"]["nameTruncated"] is True

    assert client.get("/api/planning/202620/subjects").status_code == 404
    bd.execute("UPDATE periodo_planificacion SET estado = 'borrador'")
    assert client.get("/api/planning/202710/subjects").status_code == 404


# --- Plan del estudiante -------------------------------------------------------


def test_el_plan_pide_sesion(api):
    client, _, _, _ = api
    main.app.dependency_overrides.pop(auth_routes.require_user, None)
    assert client.get("/api/planning/202710/plan").status_code == 401
    assert client.put("/api/planning/202710/plan", json={"codes": ["CBAS-M03A"]}).status_code == 401


def test_plan_vacio(api):
    client, _, _, _ = api
    r = client.get("/api/planning/202710/plan")
    assert r.status_code == 200
    assert r.json() == {"term": "202710", "editable": True, "updatedAt": None, "subjects": []}


def test_guardar_y_leer_el_plan_en_orden(api):
    client, bd, _, ids = api
    r = client.put("/api/planning/202710/plan", json={"codes": ["CHUL-I03A", "CBAS-M03A"]})
    assert r.status_code == 200
    assert _codigos(r) == ["CHUL-I03A", "CBAS-M03A"]
    assert r.json()["subjects"][1] == {"code": "CBAS-M03A", "name": "Cálculo Integral", "credits": 4.0, "active": True}
    # La fecha sale en ISO 8601 con su desfase horario.
    assert datetime.fromisoformat(r.json()["updatedAt"]).utcoffset() is not None
    leido = client.get("/api/planning/202710/plan")
    assert _codigos(leido) == ["CHUL-I03A", "CBAS-M03A"]
    assert leido.json()["updatedAt"] == r.json()["updatedAt"]

    # Repetirlo da lo mismo; otro plan lo reemplaza entero.
    assert _codigos(client.put("/api/planning/202710/plan", json={"codes": ["CHUL-I03A", "CBAS-M03A"]})) == ["CHUL-I03A", "CBAS-M03A"]
    assert _codigos(client.put("/api/planning/202710/plan", json={"codes": ["CBAS-M01B"]})) == ["CBAS-M01B"]
    assert bd.execute("SELECT COUNT(*) FROM plan_materia").fetchone()[0] == 1
    assert bd.execute("SELECT COUNT(*) FROM plan_estudiante WHERE usuario_id = %s", (ids[0],)).fetchone()[0] == 1
    # Vacío lo borra.
    assert client.put("/api/planning/202710/plan", json={"codes": []}).json()["subjects"] == []


def test_cada_estudiante_ve_solo_su_plan(api):
    client, _, entrar_como, ids = api
    # Un id en el cuerpo no cambia de quién es el plan.
    client.put("/api/planning/202710/plan", json={"codes": ["CBAS-M03A"], "usuario_id": ids[1], "db_user_id": ids[1]})
    entrar_como(2)
    assert _codigos(client.get("/api/planning/202710/plan")) == []
    client.put("/api/planning/202710/plan", json={"codes": ["RULE-I03B"]})
    entrar_como(1)
    assert _codigos(client.get("/api/planning/202710/plan")) == ["CBAS-M03A"]


def test_reglas_del_plan(api):
    client, bd, _, _ = api
    put = lambda codigos: client.put("/api/planning/202710/plan", json={"codes": codigos})  # noqa: E731

    r = put(["CBAS-M03A", "CBAS-M03A"])
    assert r.status_code == 400 and "repetida" in r.json()["detail"]
    r = put(["CBAS-M03A", "NO-EXISTE"])
    assert r.status_code == 422 and "NO-EXISTE" in r.json()["detail"]
    r = put(["IIND-P09A", "CBAS-M03A", "CBAS-M01B"])  # 15 + 4 + 3 = 22
    assert r.status_code == 422 and "20" in r.json()["detail"]
    assert put(["IIND-P09A", "CBAS-M01B", "CHUL-I03A"]).status_code == 200  # 15 + 3 + 2 = 20, justo
    assert put(["CBAS-F03A"]).status_code == 200  # sin créditos cuenta como 0
    assert client.put("/api/planning/202710/plan", json={"codes": "CBAS-M03A"}).status_code == 422
    assert client.put("/api/planning/202620/plan", json={"codes": []}).status_code == 404

    bd.execute("UPDATE periodo_planificacion SET estado = 'cerrado'")
    r = put(["CBAS-M03A"])
    assert r.status_code == 409 and "2027-1" in r.json()["detail"]
    assert client.get("/api/planning/202710/plan").json()["editable"] is False


def test_una_materia_que_sale_de_la_lista_se_conserva_si_ya_estaba(api):
    client, bd, _, _ = api
    client.put("/api/planning/202710/plan", json={"codes": ["CBAS-M01B"]})
    bd.execute("UPDATE materia_planificable SET activa = FALSE WHERE codigo IN ('CBAS-M01B', 'CBAS-M03A')")
    r = client.get("/api/planning/202710/plan")
    assert r.json()["subjects"] == [{"code": "CBAS-M01B", "name": "Cálculo Univariable", "credits": 3.0, "active": False}]
    assert client.put("/api/planning/202710/plan", json={"codes": ["CBAS-M01B", "CHUL-I03A"]}).status_code == 200
    # Una inactiva que no estaba en el plan no entra.
    r = client.put("/api/planning/202710/plan", json={"codes": ["CBAS-M03A"]})
    assert r.status_code == 422 and "CBAS-M03A" in r.json()["detail"]
