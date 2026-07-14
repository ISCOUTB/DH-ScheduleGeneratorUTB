"""
Pruebas de créditos fraccionarios (ej. 0.5).

Banner publica materias con créditos decimales. La columna `Materia.Creditos`
era INTEGER, así que Postgres redondeaba al insertar (0.5 -> 0) y la app las
mostraba con 0 créditos. Estas pruebas cubren las dos piezas que no dependen de
la base: el parser del ETL y la poda por créditos del generador.
"""
import os
import sys
from typing import Any, Dict, List

# El parser vive en backend/scripts y usa imports planos (`from utils import ...`).
sys.path.insert(
    0, os.path.join(os.path.dirname(__file__), "..", "backend", "scripts")
)

from parser import obtener_creditos  # noqa: E402
from backend.app.models import ClassOption, Schedule  # noqa: E402
from backend.app.services.schedule_generator import find_valid_schedules  # noqa: E402


# --- Parser del ETL ---

def test_creditos_decimales_no_se_truncan():
    """Una materia de 0.5 créditos en Banner llega como 0.5, no como 0."""
    assert obtener_creditos({"creditHourLow": 0.5}) == 0.5
    assert obtener_creditos({"creditHourHigh": 1.5, "creditHourLow": 1}) == 1.5


def test_creditos_enteros_y_ausentes():
    """Los enteros siguen funcionando y la ausencia de dato no revienta."""
    assert obtener_creditos({"creditHourLow": 3}) == 3.0
    assert obtener_creditos({}) == 0.0
    assert obtener_creditos({"creditHourHigh": None, "creditHourLow": None}) == 0.0


# --- Poda por créditos del generador ---

def _option(code: str, credits: float, nrc: str, day: str) -> List[List[ClassOption]]:
    """Una materia con una sola opción, en un día distinto (sin conflictos)."""
    return [[
        ClassOption(
            subjectCode=code,
            subjectName=f"Materia {code}",
            credits=credits,
            type="Teórico",
            professor="Docente",
            nrc=nrc,
            groupId=1,
            schedules=[Schedule(day=day, time="07:00 - 08:50")],
            campus="Campus Tecnológico",
            seatsAvailable=10,
            seatsMaximum=30,
        )
    ]]


def test_media_materia_cabe_en_el_limite():
    """19.5 + 0.5 = 20: la suma da justo el tope y el horario debe generarse.

    Sin tolerancia de coma flotante, una suma como esta podría quedar en
    20.000000000000004 y descartarse.
    """
    combinaciones = [
        _option("A", 19.5, "1001", "Lunes"),
        _option("B", 0.5, "1002", "Martes"),
    ]
    schedules = find_valid_schedules(combinaciones, {"max_credits": 20})

    assert len(schedules) == 1
    total = sum(o.credits for o in schedules[0])
    assert total == 20.0


def test_media_materia_por_encima_del_limite_se_poda():
    """20 + 0.5 = 20.5 excede el tope de 20: no hay horario válido."""
    combinaciones = [
        _option("A", 20, "1001", "Lunes"),
        _option("B", 0.5, "1002", "Martes"),
    ]
    assert find_valid_schedules(combinaciones, {"max_credits": 20}) == []


def test_creditos_decimales_sobreviven_al_generador():
    """El horario devuelto conserva el decimal (no se redondea a entero)."""
    combinaciones = [_option("A", 0.5, "1001", "Lunes")]
    schedules = find_valid_schedules(combinaciones, {"max_credits": 20})

    assert len(schedules) == 1
    assert schedules[0][0].credits == 0.5
