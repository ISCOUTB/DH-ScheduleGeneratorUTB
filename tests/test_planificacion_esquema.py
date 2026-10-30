"""
Esquema de la planificación del período siguiente (HU #380 de la app): la
lista de materias que el estudiante puede agregar y el plan de cada uno.

- `init.sql` (base nueva) y la migración de `migrar_esquema.py` (producción)
  crean lo mismo, y la migración se puede correr dos veces;
- una materia de la lista es única por período; un plan, por estudiante y
  período; una materia, una sola vez por plan;
- borrar la cuenta borra sus planes;
- la vista de demanda no muestra conteos de menos de 10 estudiantes.

Necesita un PostgreSQL de prueba en `DH_TEST_DATABASE_URL` (fixture `bd` de
conftest.py); sin la variable, se omiten.
"""
import importlib

import pytest

from conftest import RAIZ, URL_PRUEBA as URL

psycopg = pytest.importorskip("psycopg")

TABLAS = [
    "equivalencia_materia",
    "materia_planificable",
    "periodo_planificacion",
    "plan_estudiante",
    "plan_materia",
]


@pytest.fixture
def conn(bd):
    return bd


def _columnas(c):
    return c.execute(
        """
        SELECT table_name, column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = ANY(%s)
        ORDER BY table_name, column_name
        """,
        (TABLAS,),
    ).fetchall()


def _migrar(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", URL)
    monkeypatch.syspath_prepend(str(RAIZ / "backend" / "scripts"))
    import config
    import migrar_esquema

    importlib.reload(config)
    importlib.reload(migrar_esquema)
    migrar_esquema.aplicar_migraciones()


def _usuario(c, n):
    return c.execute(
        "INSERT INTO usuario (entra_id, email) VALUES (%s, %s) RETURNING id",
        (f"oid-{n}", f"e{n}@utb.edu.co"),
    ).fetchone()[0]


def _periodo(c):
    return c.execute(
        "INSERT INTO periodo_planificacion (periodo, etiqueta, version_lista) "
        "VALUES ('202710', '2027-1', 'pruebas') RETURNING id"
    ).fetchone()[0]


def _materia(c, periodo_id, codigo):
    return c.execute(
        "INSERT INTO materia_planificable (periodo_id, codigo, nombre) "
        "VALUES (%s, %s, %s) RETURNING id",
        (periodo_id, codigo, f"Materia {codigo}"),
    ).fetchone()[0]


def _plan(c, usuario_id, periodo_id, materias):
    plan_id = c.execute(
        "INSERT INTO plan_estudiante (usuario_id, periodo_id) VALUES (%s, %s) RETURNING id",
        (usuario_id, periodo_id),
    ).fetchone()[0]
    for posicion, materia_id in enumerate(materias):
        c.execute(
            "INSERT INTO plan_materia (plan_id, materia_id, posicion) VALUES (%s, %s, %s)",
            (plan_id, materia_id, posicion),
        )
    return plan_id


def test_init_sql_crea_las_tablas_y_la_vista(conn):
    tablas = {
        r[0]
        for r in conn.execute(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"
        ).fetchall()
    }
    assert set(TABLAS) <= tablas
    assert "demanda_planificacion" in tablas  # la vista


def test_la_migracion_crea_lo_mismo_que_init_sql_y_se_repite(conn, monkeypatch):
    esperado = _columnas(conn)
    # Una base de producción de antes: sin las tablas nuevas.
    conn.execute("DROP VIEW demanda_planificacion")
    for tabla in ["plan_materia", "plan_estudiante", "equivalencia_materia", "materia_planificable", "periodo_planificacion"]:
        conn.execute(f"DROP TABLE {tabla}")
    assert _columnas(conn) == []

    _migrar(monkeypatch)
    _migrar(monkeypatch)  # idempotente
    assert _columnas(conn) == esperado
    assert conn.execute("SELECT to_regclass('public.demanda_planificacion')").fetchone()[0]


def test_reglas_de_unicidad(conn):
    periodo = _periodo(conn)
    a = _materia(conn, periodo, "CBAS-M03A")
    b = _materia(conn, periodo, "CBAS-M01B")
    with pytest.raises(psycopg.errors.UniqueViolation):
        _materia(conn, periodo, "CBAS-M03A")
    # Un par de equivalentes se guarda una sola vez, con el id menor primero.
    menor, mayor = sorted([a, b])
    conn.execute(
        "INSERT INTO equivalencia_materia (periodo_id, materia_a_id, materia_b_id) VALUES (%s, %s, %s)",
        (periodo, menor, mayor),
    )
    with pytest.raises(psycopg.errors.CheckViolation):
        conn.execute(
            "INSERT INTO equivalencia_materia (periodo_id, materia_a_id, materia_b_id) VALUES (%s, %s, %s)",
            (periodo, mayor, menor),
        )
    usuario = _usuario(conn, 1)
    plan = _plan(conn, usuario, periodo, [a])
    with pytest.raises(psycopg.errors.UniqueViolation):
        _plan(conn, usuario, periodo, [b])
    with pytest.raises(psycopg.errors.UniqueViolation):
        conn.execute(
            "INSERT INTO plan_materia (plan_id, materia_id, posicion) VALUES (%s, %s, 1)",
            (plan, a),
        )


def test_borrar_la_cuenta_borra_sus_planes(conn):
    periodo = _periodo(conn)
    a = _materia(conn, periodo, "CBAS-M03A")
    usuario = _usuario(conn, 1)
    _plan(conn, usuario, periodo, [a])
    conn.execute("DELETE FROM usuario WHERE id = %s", (usuario,))
    assert conn.execute("SELECT COUNT(*) FROM plan_estudiante").fetchone()[0] == 0
    assert conn.execute("SELECT COUNT(*) FROM plan_materia").fetchone()[0] == 0


def test_la_demanda_no_muestra_menos_de_10_estudiantes(conn):
    periodo = _periodo(conn)
    a = _materia(conn, periodo, "CBAS-M03A")
    b = _materia(conn, periodo, "CBAS-M01B")
    for n in range(10):
        materias = [a, b] if n < 9 else [a]
        _plan(conn, _usuario(conn, n), periodo, materias)
    filas = conn.execute(
        "SELECT periodo, codigo, estudiantes FROM demanda_planificacion ORDER BY codigo"
    ).fetchall()
    assert filas == [("202710", "CBAS-M03A", 10)]
