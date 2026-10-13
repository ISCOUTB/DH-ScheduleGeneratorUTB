"""
Pruebas de la autenticación por token (Bearer) para la app móvil
(backend/app/auth/token_auth.py y la dependencia `require_user`).

Sin red ni base de datos: Graph, el registro del usuario y el de accesos se
reemplazan. Los tokens son JWT firmados con una clave de prueba (el código
solo lee sus claims; la verificación real la hace Graph, aquí simulado).
"""
import asyncio
import os
import sys

import pytest
from jose import jwt

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))

TENANT = "tenant-utb"

# auth/routes.py lee el tenant al importarse (sin él, falla en `.split`).
os.environ.setdefault("AZURE_TENANT_ID", TENANT)

from app.auth import token_auth  # noqa: E402
from app.auth import routes as auth_routes  # noqa: E402

OID = "oid-estudiante"
NOW = 1_800_000_000.0


def make_token(**claims) -> str:
    base = {"tid": TENANT, "oid": OID, "exp": NOW + 3600}
    base.update(claims)
    return jwt.encode(base, "clave-de-prueba", algorithm="HS256")


class Fakes:
    """Graph, base de datos y reloj simulados, con registro de llamadas."""

    def __init__(self, me=None, unavailable=False):
        self.me = me if me is not None else {
            "id": OID,
            "userPrincipalName": "estudiante@utb.edu.co",
            "mail": "otro@utb.edu.co",
            "displayName": "Estudiante Prueba",
        }
        self.unavailable = unavailable
        self.graph_calls = 0
        self.persisted = []
        self.accesses = []
        self.now = NOW

    async def graph_me(self, token):
        self.graph_calls += 1
        if self.unavailable:
            raise token_auth.TokenVerificationUnavailable("sin red")
        return self.me or None

    async def persist_user(self, entra_id, email, nombre):
        self.persisted.append((entra_id, email, nombre))
        return {"id": 7, "created_at": "2026-10-13"}

    async def register_access(self, user_id, ip, user_agent):
        self.accesses.append((user_id, ip, user_agent))

    def verify(self, token, tenants=(TENANT,)):
        return asyncio.run(
            token_auth.user_from_token(
                token,
                list(tenants),
                client_ip="1.2.3.4",
                user_agent="UTBApp",
                graph_me=self.graph_me,
                persist_user=self.persist_user,
                register_access=self.register_access,
                now=lambda: self.now,
            )
        )


@pytest.fixture(autouse=True)
def _clean_cache():
    token_auth.clear_cache()
    yield
    token_auth.clear_cache()


def test_bearer_token_parsing():
    assert token_auth.bearer_token("Bearer abc") == "abc"
    assert token_auth.bearer_token("bearer  abc ") == "abc"
    assert token_auth.bearer_token("Basic abc") is None
    assert token_auth.bearer_token("Bearer") is None
    assert token_auth.bearer_token(None) is None


def test_valid_token_gives_web_shaped_user_and_is_cached():
    fakes = Fakes()
    token = make_token()
    user = fakes.verify(token)
    assert user == {
        "id": OID,
        # Mismo correo que el login web (UPN), no `mail`.
        "email": "estudiante@utb.edu.co",
        "nombre": "Estudiante Prueba",
        "tenant_id": TENANT,
        "db_user_id": 7,
        "db_user_created_at": "2026-10-13",
    }
    assert fakes.persisted == [(OID, "estudiante@utb.edu.co", "Estudiante Prueba")]
    assert fakes.accesses == [(7, "1.2.3.4", "UTBApp")]

    # La segunda vez no llama a Graph ni registra otro acceso.
    assert fakes.verify(token) == user
    assert fakes.graph_calls == 1
    assert len(fakes.accesses) == 1


def test_expired_token_is_rejected_without_graph():
    fakes = Fakes()
    assert fakes.verify(make_token(exp=NOW - 1)) is None
    assert fakes.graph_calls == 0


def test_cached_token_expires_with_its_exp():
    fakes = Fakes()
    token = make_token(exp=NOW + 60)
    assert fakes.verify(token) is not None
    fakes.now = NOW + 61
    assert fakes.verify(token) is None
    assert fakes.graph_calls == 1


def test_other_tenant_is_rejected_without_graph():
    fakes = Fakes()
    assert fakes.verify(make_token(tid="otro-tenant")) is None
    assert fakes.graph_calls == 0


def test_not_a_jwt_is_rejected():
    fakes = Fakes()
    assert fakes.verify("no-es-un-jwt") is None
    assert fakes.graph_calls == 0


def test_graph_rejection_is_rejected_and_not_cached():
    fakes = Fakes(me={})
    token = make_token()
    assert fakes.verify(token) is None
    assert fakes.verify(token) is None
    assert fakes.graph_calls == 2
    assert fakes.persisted == []


def test_graph_user_must_match_token_oid():
    fakes = Fakes(me={"id": "otro-oid", "userPrincipalName": "x@utb.edu.co"})
    assert fakes.verify(make_token()) is None
    assert fakes.persisted == []


def test_graph_unavailable_raises():
    fakes = Fakes(unavailable=True)
    with pytest.raises(token_auth.TokenVerificationUnavailable):
        fakes.verify(make_token())


# --- La dependencia `require_user` en una ruta real -------------------------

@pytest.fixture
def client(monkeypatch):
    from fastapi import Depends, FastAPI
    from fastapi.testclient import TestClient

    fakes = Fakes()
    monkeypatch.setattr(token_auth, "_graph_me", fakes.graph_me)
    monkeypatch.setattr(token_auth, "_persist_user", fakes.persist_user)
    monkeypatch.setattr(token_auth, "_register_access", fakes.register_access)
    # Los tokens vencen en NOW + 1 h (2027): vigentes con el reloj real.
    monkeypatch.setattr(auth_routes, "ALLOWED_TENANTS", [TENANT])

    app = FastAPI()

    @app.get("/privada")
    async def privada(user: dict = Depends(auth_routes.require_user)):
        return {"email": user["email"], "db_user_id": user.get("db_user_id")}

    auth_routes.sessions["sesion-web"] = {
        "id": "oid-web",
        "email": "web@utb.edu.co",
        "nombre": "Web",
        "db_user_id": 3,
    }
    yield TestClient(app), fakes
    auth_routes.sessions.pop("sesion-web", None)


def test_route_accepts_web_cookie(client):
    http, fakes = client
    http.cookies.set("session_id", "sesion-web")
    response = http.get("/privada")
    assert response.status_code == 200
    assert response.json() == {"email": "web@utb.edu.co", "db_user_id": 3}
    assert fakes.graph_calls == 0


def test_route_accepts_bearer_token(client):
    http, _ = client
    response = http.get(
        "/privada", headers={"Authorization": f"Bearer {make_token()}"}
    )
    assert response.status_code == 200
    assert response.json() == {"email": "estudiante@utb.edu.co", "db_user_id": 7}


def test_route_without_credentials_is_401(client):
    http, _ = client
    assert http.get("/privada").status_code == 401
    bad = http.get("/privada", headers={"Authorization": "Bearer no-es-un-jwt"})
    assert bad.status_code == 401


def test_route_with_graph_down_is_503(client):
    http, fakes = client
    fakes.unavailable = True
    response = http.get(
        "/privada", headers={"Authorization": f"Bearer {make_token()}"}
    )
    assert response.status_code == 503
