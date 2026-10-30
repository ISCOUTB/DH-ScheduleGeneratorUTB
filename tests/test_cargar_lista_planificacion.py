"""
Carga de la lista de materias del período siguiente
(`backend/scripts/cargar_lista_planificacion.py`), desde el JSON que genera
`exportar_lista.py`:

- leer: sin período, sin materias o con un código repetido no es una lista;
  cada par de equivalentes queda una sola vez y solo si las dos materias
  están en la lista; sin créditos queda sin créditos (no 0);
- cargar (necesita `DH_TEST_DATABASE_URL`): crea el período abierto con sus
  materias y equivalencias; volver a cargar lo mismo no cambia nada; una
  materia que ya no viene queda inactiva, sin borrarse ni romper los planes
  que la tienen, y vuelve a estar activa si regresa; las equivalencias se
  reemplazan.
"""
import pytest

from conftest import RAIZ

import sys

sys.path.insert(0, str(RAIZ / "backend" / "scripts"))

import cargar_lista_planificacion as carga  # noqa: E402


def _json(*materias, version="pruebas-2026-10-29"):
    return {
        "term": "202710",
        "termLabel": "2027-1",
        "listVersion": version,
        "policy": "all-candidates",
        "subjects": list(materias),
    }


def _materia(codigo, nombre=None, creditos=3, equivalentes=()):
    return {
        "code": codigo,
        "name": nombre or f"Materia {codigo}",
        "bannerName": (nombre or f"MATERIA {codigo}").upper(),
        "nameTruncated": False,
        "subject": codigo[:4],
        "credits": creditos,
        "levels": ["UG"],
        "programs": ["Ingeniería de Sistemas y Computación"],
        "equivalentCodes": list(equivalentes),
    }


# --- Leer el JSON (sin base de datos) ---------------------------------------


def test_leer_una_lista_valida():
    lista = carga.leer_lista(
        _json(
            _materia("CHUL-I03A", "Inglés III", 2, ["RULE-I03B"]),
            _materia("RULE-I03B", "Inglés III", 2, ["CHUL-I03A", "FUERA-0001"]),
            _materia("CBAS-F03A", "Física Calor y Ondas", None),
        )
    )
    assert lista.periodo == "202710"
    assert lista.etiqueta == "2027-1"
    assert lista.version == "pruebas-2026-10-29"
    assert [m["codigo"] for m in lista.materias] == ["CHUL-I03A", "RULE-I03B", "CBAS-F03A"]
    assert lista.materias[2]["creditos"] is None
    # El par va una vez y el equivalente que no está en la lista se ignora.
    assert lista.equivalencias == [("CHUL-I03A", "RULE-I03B")]


@pytest.mark.parametrize(
    "datos, motivo",
    [
        ({"termLabel": "2027-1", "listVersion": "v", "subjects": [_materia("A-1")]}, "período"),
        (_json() | {"term": "2027"}, "período"),
        (_json(), "materias"),
        (_json(_materia("A-1"), _materia("A-1")), "repetido"),
        (_json(_materia("A-1") | {"name": " "}), "nombre"),
    ],
)
def test_lo_que_no_es_una_lista(datos, motivo):
    with pytest.raises(ValueError, match=motivo):
        carga.leer_lista(datos)


# --- Cargar en la base (DH_TEST_DATABASE_URL) -------------------------------


def _materias(bd):
    return {
        codigo: (activa, creditos)
        for codigo, activa, creditos in bd.execute(
            "SELECT codigo, activa, creditos FROM materia_planificable ORDER BY codigo"
        ).fetchall()
    }


def _pares(bd):
    return bd.execute(
        """
        SELECT a.codigo, b.codigo FROM equivalencia_materia e
        JOIN materia_planificable a ON a.id = e.materia_a_id
        JOIN materia_planificable b ON b.id = e.materia_b_id
        ORDER BY 1, 2
        """
    ).fetchall()


def test_cargar_crea_el_periodo_abierto_con_sus_materias(bd):
    lista = carga.leer_lista(
        _json(
            _materia("CHUL-I03A", "Inglés III", 2, ["RULE-I03B"]),
            _materia("RULE-I03B", "Inglés III", 2, ["CHUL-I03A"]),
            _materia("CBAS-F03A", "Física Calor y Ondas", None),
        )
    )
    resumen = carga.cargar(bd, lista)
    assert resumen == {"periodo": "202710", "materias": 3, "nuevas": 3, "inactivadas": 0, "equivalencias": 1}
    assert bd.execute(
        "SELECT etiqueta, version_lista, estado FROM periodo_planificacion"
    ).fetchone() == ("2027-1", "pruebas-2026-10-29", "abierto")
    assert _materias(bd) == {"CBAS-F03A": (True, None), "CHUL-I03A": (True, 2), "RULE-I03B": (True, 2)}
    assert _pares(bd) == [("CHUL-I03A", "RULE-I03B")]


def test_volver_a_cargar_lo_mismo_no_cambia_nada(bd):
    datos = _json(_materia("A-1", equivalentes=["B-1"]), _materia("B-1", equivalentes=["A-1"]))
    carga.cargar(bd, carga.leer_lista(datos))
    antes = (_materias(bd), _pares(bd))
    resumen = carga.cargar(bd, carga.leer_lista(datos))
    assert resumen["nuevas"] == 0 and resumen["inactivadas"] == 0
    assert (_materias(bd), _pares(bd)) == antes
    assert bd.execute("SELECT COUNT(*) FROM periodo_planificacion").fetchone()[0] == 1


def test_una_materia_que_sale_queda_inactiva_y_el_plan_sigue(bd):
    carga.cargar(bd, carga.leer_lista(_json(_materia("A-1", equivalentes=["B-1"]), _materia("B-1", equivalentes=["A-1"]))))
    # Un estudiante ya la tiene en su plan.
    usuario = bd.execute("INSERT INTO usuario (entra_id, email) VALUES ('oid', 'e@utb.edu.co') RETURNING id").fetchone()[0]
    periodo_id, materia_id = bd.execute(
        "SELECT periodo_id, id FROM materia_planificable WHERE codigo = 'B-1'"
    ).fetchone()
    plan = bd.execute(
        "INSERT INTO plan_estudiante (usuario_id, periodo_id) VALUES (%s, %s) RETURNING id", (usuario, periodo_id)
    ).fetchone()[0]
    bd.execute("INSERT INTO plan_materia (plan_id, materia_id, posicion) VALUES (%s, %s, 0)", (plan, materia_id))

    resumen = carga.cargar(bd, carga.leer_lista(_json(_materia("A-1"), version="v2")))
    assert resumen["inactivadas"] == 1
    assert _materias(bd) == {"A-1": (True, 3), "B-1": (False, 3)}
    assert _pares(bd) == []  # las equivalencias se reemplazan
    assert bd.execute("SELECT COUNT(*) FROM plan_materia").fetchone()[0] == 1
    assert bd.execute("SELECT version_lista FROM periodo_planificacion").fetchone()[0] == "v2"

    # Si vuelve, vuelve activa.
    carga.cargar(bd, carga.leer_lista(_json(_materia("A-1"), _materia("B-1"))))
    assert _materias(bd)["B-1"] == (True, 3)


def test_una_carga_que_falla_no_deja_nada_a_medias(bd, monkeypatch):
    carga.cargar(bd, carga.leer_lista(_json(_materia("A-1"))))

    def falla(*_):
        raise RuntimeError("se cayó la conexión")

    monkeypatch.setattr(carga, "_reemplazar_equivalencias", falla)
    with pytest.raises(RuntimeError):
        carga.cargar(bd, carga.leer_lista(_json(_materia("B-1"), version="v2")))
    assert _materias(bd) == {"A-1": (True, 3)}
    assert bd.execute("SELECT version_lista FROM periodo_planificacion").fetchone()[0] == "pruebas-2026-10-29"
