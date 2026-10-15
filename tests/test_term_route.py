"""
Pruebas de la ruta pública del período actual (`GET /api/term`).

Devuelve `CURRENT_TERM` (el período de la oferta, en código de Banner) sin
pedir sesión: la usa la app móvil para mostrar el período sobre la lista de
materias. Sin red ni base de datos (la ruta no las toca).
"""
import os
import sys

from fastapi.testclient import TestClient

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))

# auth/routes.py lee el tenant al importarse (sin él, falla en `.split`).
os.environ.setdefault("AZURE_TENANT_ID", "tenant-utb")

from app import main  # noqa: E402

client = TestClient(main.app)


def test_devuelve_el_periodo_actual_sin_sesion(monkeypatch):
    monkeypatch.setattr(main, "CURRENT_TERM", "202620")
    response = client.get("/api/term")
    assert response.status_code == 200
    assert response.json() == {"currentTerm": "202620"}


def test_es_el_mismo_periodo_de_destacados():
    # Una sola fuente: el `CURRENT_TERM` del .env que leen la API y el ETL.
    from app.auth.routes import CURRENT_TERM

    assert client.get("/api/term").json() == {"currentTerm": CURRENT_TERM}
