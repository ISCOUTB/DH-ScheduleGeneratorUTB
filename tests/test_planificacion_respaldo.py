"""
Los datos de la planificación (HU #380 de la app) sobreviven al ETL y entran
en los respaldos (`backend/scripts/backup.py`):

- las tablas de la planificación están en `PRESERVED_APP_TABLES`, la lista que
  respalda `hacer_snapshot` cada 4 horas;
- `limpiar_tablas`, que el ETL corre antes de reinsertar la oferta, no las
  toca (necesita `DH_TEST_DATABASE_URL`).
"""
import sys

from conftest import RAIZ

sys.path.insert(0, str(RAIZ / "backend" / "scripts"))

import backup  # noqa: E402

TABLAS_PLANIFICACION = (
    "periodo_planificacion",
    "materia_planificable",
    "equivalencia_materia",
    "plan_estudiante",
    "plan_materia",
)


def test_las_tablas_de_la_planificacion_entran_al_respaldo():
    assert set(TABLAS_PLANIFICACION) <= set(backup.PRESERVED_APP_TABLES)


def test_la_limpieza_del_etl_no_borra_los_planes(bd):
    periodo = bd.execute(
        "INSERT INTO periodo_planificacion (periodo, etiqueta, version_lista) "
        "VALUES ('202710', '2027-1', 'v') RETURNING id"
    ).fetchone()[0]
    materias = [
        bd.execute(
            "INSERT INTO materia_planificable (periodo_id, codigo, nombre) VALUES (%s, %s, %s) RETURNING id",
            (periodo, codigo, codigo),
        ).fetchone()[0]
        for codigo in ("A-1", "B-1")
    ]
    bd.execute(
        "INSERT INTO equivalencia_materia (periodo_id, materia_a_id, materia_b_id) VALUES (%s, %s, %s)",
        (periodo, *sorted(materias)),
    )
    usuario = bd.execute(
        "INSERT INTO usuario (entra_id, email) VALUES ('oid', 'e@utb.edu.co') RETURNING id"
    ).fetchone()[0]
    plan = bd.execute(
        "INSERT INTO plan_estudiante (usuario_id, periodo_id) VALUES (%s, %s) RETURNING id",
        (usuario, periodo),
    ).fetchone()[0]
    bd.execute("INSERT INTO plan_materia (plan_id, materia_id, posicion) VALUES (%s, %s, 0)", (plan, materias[0]))

    backup.limpiar_tablas(bd)

    conteos = {
        tabla: bd.execute(f"SELECT COUNT(*) FROM {tabla}").fetchone()[0]
        for tabla in TABLAS_PLANIFICACION
    }
    assert conteos == {
        "periodo_planificacion": 1,
        "materia_planificable": 2,
        "equivalencia_materia": 1,
        "plan_estudiante": 1,
        "plan_materia": 1,
    }
