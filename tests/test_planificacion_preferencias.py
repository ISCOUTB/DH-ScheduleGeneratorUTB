"""
Preferencias de horario del plan (`/api/planning/{term}/preferences`), con la
base de prueba (`DH_TEST_DATABASE_URL`, fixture `api` de conftest.py):

- piden sesión (401 sin ella); son de quien tiene la sesión, nunca de un id
  que venga en el cuerpo;
- el `GET` da `{term, editable, updatedAt, dayParts, preferredFreeDays,
  reasons}`, cada lista en el orden canónico y vacía si no respondió; 404 si
  el período no existe o es un borrador;
- el `PUT` reemplaza las tres respuestas (una lista que no viene queda vacía)
  y devuelve lo mismo que el `GET`; 422 con una opción desconocida (la nombra)
  o con `noPreference`/`preferNotToSay` junto a otra opción de su pregunta;
  400 con una opción repetida; 409 si el período no está abierto o está fuera
  de su ventana, revisado también dentro de la transacción del guardado;
- responder sin materias crea el plan vacío, y el plan y las preferencias no
  se pisan.
"""
import os
from datetime import datetime, timedelta, timezone

import pytest

from conftest import RAIZ

import sys

sys.path.insert(0, str(RAIZ / "backend"))
os.environ.setdefault("AZURE_TENANT_ID", "tenant-utb")

from app import main  # noqa: E402
from app.auth import routes as auth_routes  # noqa: E402
from app.db import repository  # noqa: E402

URL = "/api/planning/202710/preferences"
VACIAS = {"dayParts": [], "preferredFreeDays": [], "reasons": []}


def _guardadas(bd, usuario_id):
    """(jornadas, dias_libres, motivos, respondió) del plan guardado, o None."""
    fila = bd.execute(
        """
        SELECT jornadas, dias_libres, motivos, preferencias_actualizadas IS NOT NULL
        FROM plan_estudiante WHERE usuario_id = %s
        """,
        (usuario_id,),
    ).fetchone()
    return tuple(fila) if fila else None


def test_las_preferencias_piden_sesion(api):
    client, bd, _, _ = api
    main.app.dependency_overrides.pop(auth_routes.require_user, None)
    assert client.get(URL).status_code == 401
    assert client.put(URL, json={"dayParts": ["night"]}).status_code == 401
    assert bd.execute("SELECT COUNT(*) FROM plan_estudiante").fetchone()[0] == 0


def test_sin_responder_estan_vacias(api):
    client, bd, _, _ = api
    r = client.get(URL)
    assert r.status_code == 200
    assert r.json() == {"term": "202710", "editable": True, "updatedAt": None, **VACIAS}
    # Leer no crea el plan.
    assert bd.execute("SELECT COUNT(*) FROM plan_estudiante").fetchone()[0] == 0


def test_guardar_y_leer_en_el_orden_canonico(api):
    client, bd, _, ids = api
    r = client.put(URL, json={
        "dayParts": ["night", "morning"],
        "preferredFreeDays": ["Sábado", "Miércoles", "Lunes"],
        "reasons": ["other", "work"],
    })
    assert r.status_code == 200
    cuerpo = r.json()
    assert cuerpo == {
        "term": "202710",
        "editable": True,
        "updatedAt": cuerpo["updatedAt"],
        "dayParts": ["morning", "night"],
        "preferredFreeDays": ["Lunes", "Miércoles", "Sábado"],
        "reasons": ["work", "other"],
    }
    assert datetime.fromisoformat(cuerpo["updatedAt"]).utcoffset() is not None
    assert client.get(URL).json() == cuerpo
    assert _guardadas(bd, ids[0]) == (["morning", "night"], ["Lunes", "Miércoles", "Sábado"], ["work", "other"], True)

    # Reemplaza las tres: lo que no viene (o viene null) queda vacío.
    r = client.put(URL, json={"dayParts": ["noPreference"], "reasons": None})
    assert r.status_code == 200
    assert {k: r.json()[k] for k in VACIAS} == {"dayParts": ["noPreference"], "preferredFreeDays": [], "reasons": []}
    assert _guardadas(bd, ids[0]) == (["noPreference"], [], [], True)
    assert bd.execute("SELECT COUNT(*) FROM plan_estudiante").fetchone()[0] == 1


def test_responder_sin_materias_crea_el_plan_vacio(api):
    client, bd, _, ids = api
    assert client.put(URL, json={"preferredFreeDays": ["Viernes"]}).status_code == 200
    assert bd.execute("SELECT COUNT(*) FROM plan_estudiante WHERE usuario_id = %s", (ids[0],)).fetchone()[0] == 1
    assert bd.execute("SELECT COUNT(*) FROM plan_materia").fetchone()[0] == 0
    # El plan de materias sigue vacío y sin fecha: nunca se guardó.
    plan = client.get("/api/planning/202710/plan")
    assert plan.status_code == 200
    assert plan.json() == {"term": "202710", "editable": True, "updatedAt": None, "subjects": []}

    # Guardar el plan no toca las preferencias, y al revés.
    antes = client.get(URL).json()
    plan = client.put("/api/planning/202710/plan", json={"codes": ["CBAS-M03A"]}).json()
    assert plan["updatedAt"] is not None
    assert client.get(URL).json() == antes
    client.put(URL, json={"dayParts": ["afternoon"]})
    assert client.get("/api/planning/202710/plan").json() == plan


def test_cada_estudiante_ve_solo_sus_preferencias(api):
    client, bd, entrar_como, ids = api
    # Un id en el cuerpo no cambia de quién son.
    r = client.put(URL, json={"dayParts": ["night"], "usuario_id": ids[1], "db_user_id": ids[1]})
    assert r.status_code == 200
    assert _guardadas(bd, ids[0]) == (["night"], [], [], True)
    assert _guardadas(bd, ids[1]) is None
    entrar_como(2)
    assert {k: client.get(URL).json()[k] for k in VACIAS} == VACIAS
    client.put(URL, json={"reasons": ["work"]})
    entrar_como(1)
    assert {k: client.get(URL).json()[k] for k in VACIAS} == {"dayParts": ["night"], "preferredFreeDays": [], "reasons": []}
    assert _guardadas(bd, ids[1]) == ([], [], ["work"], True)


@pytest.mark.parametrize(
    "cuerpo, nombrado",
    [
        ({"dayParts": ["evening"]}, "evening"),
        ({"preferredFreeDays": ["Lunes", "Domingo"]}, "Domingo"),
        ({"preferredFreeDays": ["lunes"]}, "lunes"),
        ({"reasons": ["study"]}, "study"),
    ],
)
def test_una_opcion_desconocida_da_422_y_la_nombra(api, cuerpo, nombrado):
    client, bd, _, ids = api
    r = client.put(URL, json=cuerpo)
    assert r.status_code == 422
    assert nombrado in r.json()["detail"]
    assert _guardadas(bd, ids[0]) is None


@pytest.mark.parametrize(
    "cuerpo, exclusiva",
    [
        ({"dayParts": ["morning", "noPreference"]}, "noPreference"),
        ({"reasons": ["preferNotToSay", "work"]}, "preferNotToSay"),
    ],
)
def test_la_opcion_exclusiva_va_sola(api, cuerpo, exclusiva):
    client, bd, _, ids = api
    r = client.put(URL, json=cuerpo)
    assert r.status_code == 422
    assert exclusiva in r.json()["detail"]
    assert _guardadas(bd, ids[0]) is None
    # Sola sí.
    r = client.put(URL, json={campo: [exclusiva] for campo in cuerpo})
    assert r.status_code == 200
    assert r.json()[next(iter(cuerpo))] == [exclusiva]


def test_una_opcion_repetida_da_400(api):
    client, bd, _, ids = api
    r = client.put(URL, json={"dayParts": ["night", "night"]})
    assert r.status_code == 400
    assert "night" in r.json()["detail"]
    assert _guardadas(bd, ids[0]) is None


def test_un_cuerpo_que_no_es_una_lista_da_422(api):
    client, bd, _, ids = api
    assert client.put(URL, json={"dayParts": "night"}).status_code == 422
    assert client.put(URL, json={"reasons": [1]}).status_code == 422
    assert _guardadas(bd, ids[0]) is None


def test_periodo_cerrado_o_fuera_de_su_ventana_da_409(api):
    client, bd, _, ids = api
    client.put(URL, json={"dayParts": ["morning"]})
    antes = _guardadas(bd, ids[0])
    ahora = datetime.now(timezone.utc)

    for cambio, valores in [
        ("estado = 'cerrado'", ()),
        ("abre = %s", (ahora + timedelta(days=1),)),  # aún no abre
        ("cierra = %s", (ahora - timedelta(days=1),)),  # ya cerró
    ]:
        bd.execute("UPDATE periodo_planificacion SET estado = 'abierto', abre = NULL, cierra = NULL")
        bd.execute(f"UPDATE periodo_planificacion SET {cambio}", valores)
        r = client.put(URL, json={"dayParts": ["night"]})
        assert r.status_code == 409, cambio
        assert "2027-1" in r.json()["detail"]
        assert _guardadas(bd, ids[0]) == antes
        # Se pueden leer, sin editar.
        leidas = client.get(URL)
        assert leidas.status_code == 200 and leidas.json()["editable"] is False
        assert leidas.json()["dayParts"] == ["morning"]


def test_el_periodo_se_revisa_dentro_de_la_transaccion(api, monkeypatch):
    client, bd, _, ids = api
    # El período se cierra entre la primera lectura y el guardado.
    leer = repository.get_planning_term

    def leido_antes_de_cerrar(term):
        periodo = leer(term)
        bd.execute("UPDATE periodo_planificacion SET estado = 'cerrado'")
        return periodo

    monkeypatch.setattr(repository, "get_planning_term", leido_antes_de_cerrar)
    r = client.put(URL, json={"dayParts": ["night"]})
    assert r.status_code == 409
    assert r.json()["detail"] == "La planificación de 2027-1 no está abierta."
    # No queda nada a medias: ni el plan vacío.
    assert _guardadas(bd, ids[0]) is None


def test_periodo_desconocido_o_borrador_da_404(api):
    client, bd, _, _ = api
    assert client.get("/api/planning/202620/preferences").status_code == 404
    assert client.put("/api/planning/202620/preferences", json={}).status_code == 404
    bd.execute("UPDATE periodo_planificacion SET estado = 'borrador'")
    assert client.get(URL).status_code == 404
    assert client.put(URL, json={"dayParts": ["night"]}).status_code == 404
    assert bd.execute("SELECT COUNT(*) FROM plan_estudiante").fetchone()[0] == 0
