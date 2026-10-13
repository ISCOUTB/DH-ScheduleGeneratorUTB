# auth/token_auth.py
"""
Autenticación por token (Bearer) para clientes que no usan la cookie de la web,
como la app móvil institucional (UTB App).

**Solución temporal** (ver docs/issues/13-10-2026-auth-token-app-movil.md):
la app inicia sesión con Microsoft por su cuenta y obtiene un access token
de **Microsoft Graph** (`User.Read`). Ese token no se puede verificar
localmente (su firma es para Graph), así que se le pregunta a Graph quién es
(`GET /v1.0/me`): si Graph lo acepta, el token es válido y trae el `id` (el
mismo `oid` que guarda el login web) y el correo del usuario.

El usuario resultante tiene la misma forma que una sesión web (`sessions[...]`
en auth/routes.py), así que las rutas no distinguen el origen.

Riesgo aceptado mientras dure la solución temporal: se acepta cualquier token
de Graph del usuario, aunque lo haya emitido otra aplicación del tenant. La
solución definitiva (exponer la API del generador en Entra ID y validar
firma, `aud` y `scp` localmente) está documentada en el issue.
"""
import hashlib
import os
import time
from typing import Awaitable, Callable, Optional

import httpx
from fastapi.concurrency import run_in_threadpool
from jose import jwt

from ..db import repository

# Endpoint de Graph que identifica al dueño del token.
GRAPH_ME_URL = os.getenv(
    "GRAPH_ME_URL",
    "https://graph.microsoft.com/v1.0/me?$select=id,userPrincipalName,mail,displayName",
)

# Tiempo máximo de espera a Graph (segundos).
GRAPH_TIMEOUT = float(os.getenv("GRAPH_TIMEOUT_SECONDS", "8"))

# Cuánto se recuerda un token ya verificado: hasta su `exp`, con este tope
# (segundos). Evita una llamada a Graph por cada petición de la app.
MAX_CACHE_SECONDS = 3600

# Tope de tokens en memoria (al pasarlo se descartan los vencidos y, si no
# alcanza, los más viejos).
MAX_CACHE_ENTRIES = 2000

# Tipo del registro en `sesion_usuario` para los accesos desde la app.
LOGIN_KIND = "app"


class TokenVerificationUnavailable(Exception):
    """Graph no respondió: no se sabe si el token es válido (no es un 401)."""


# hash del token → (expira_en, usuario)
_cache: dict[str, tuple[float, dict]] = {}


def _cache_key(token: str) -> str:
    # Nunca se guarda el token en claro.
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _prune(now: float) -> None:
    for key in [k for k, (exp, _) in _cache.items() if exp <= now]:
        _cache.pop(key, None)
    if len(_cache) > MAX_CACHE_ENTRIES:
        oldest = sorted(_cache.items(), key=lambda item: item[1][0])
        for key, _ in oldest[: len(_cache) - MAX_CACHE_ENTRIES]:
            _cache.pop(key, None)


def clear_cache() -> None:
    """Olvida los tokens verificados (pruebas y cierre de sesión global)."""
    _cache.clear()


def bearer_token(authorization: Optional[str]) -> Optional[str]:
    """El token de un encabezado `Authorization: Bearer <token>`; `None` si no lo es."""
    if not authorization:
        return None
    scheme, _, token = authorization.strip().partition(" ")
    token = token.strip()
    if scheme.lower() != "bearer" or not token:
        return None
    return token


async def _graph_me(token: str) -> Optional[dict]:
    """Datos del dueño del token según Graph; `None` si Graph lo rechaza."""
    try:
        async with httpx.AsyncClient(timeout=GRAPH_TIMEOUT) as client:
            response = await client.get(
                GRAPH_ME_URL, headers={"Authorization": f"Bearer {token}"}
            )
    except httpx.HTTPError as e:
        raise TokenVerificationUnavailable(str(e)) from e
    if response.status_code in (401, 403):
        return None
    if response.status_code != 200:
        raise TokenVerificationUnavailable(f"Graph respondió {response.status_code}")
    return response.json()


async def _persist_user(entra_id: str, email: str, nombre: Optional[str]) -> dict:
    return await run_in_threadpool(repository.get_or_create_user, entra_id, email, nombre)


async def _register_access(user_id: int, client_ip: Optional[str], user_agent: Optional[str]) -> None:
    try:
        await run_in_threadpool(
            repository.register_login, user_id, client_ip, user_agent, LOGIN_KIND
        )
    except Exception as e:  # el registro es métrica: nunca bloquea la petición
        print(f"Warning: no se pudo registrar el acceso desde la app: {e}")


async def user_from_token(
    token: str,
    allowed_tenants: list[str],
    *,
    client_ip: Optional[str] = None,
    user_agent: Optional[str] = None,
    graph_me: Optional[Callable[[str], Awaitable[Optional[dict]]]] = None,
    persist_user: Optional[Callable[[str, str, Optional[str]], Awaitable[dict]]] = None,
    register_access: Optional[Callable[[int, Optional[str], Optional[str]], Awaitable[None]]] = None,
    now: Optional[Callable[[], float]] = None,
) -> Optional[dict]:
    """
    El usuario dueño de [token], con la forma de una sesión web; `None` si el
    token no es válido, venció o es de un tenant no permitido.

    Lanza `TokenVerificationUnavailable` si Graph no responde (la ruta lo
    convierte en 503, no en 401: el token puede ser válido).

    `graph_me`, `persist_user`, `register_access` y `now` existen para las
    pruebas; por defecto, Graph, la base de datos y el reloj reales.
    """
    graph_me = graph_me or _graph_me
    persist_user = persist_user or _persist_user
    register_access = register_access or _register_access
    current = (now or time.time)()
    key = _cache_key(token)
    hit = _cache.get(key)
    if hit and hit[0] > current:
        return hit[1]

    # Los claims sin verificar solo sirven para descartar rápido (vencido,
    # otro tenant) sin llamar a Graph; la verificación real es la de Graph.
    try:
        claims = jwt.get_unverified_claims(token)
    except Exception:
        return None
    exp = claims.get("exp")
    if isinstance(exp, (int, float)) and exp <= current:
        return None
    tenant = claims.get("tid")
    if tenant not in allowed_tenants:
        return None

    me = await graph_me(token)
    if not me:
        return None
    oid = me.get("id")
    # Mismo correo que el login web (`preferred_username` ≈ UPN).
    email = me.get("userPrincipalName") or me.get("mail")
    if not oid or not email or oid != claims.get("oid"):
        return None

    db_user = await persist_user(oid, email, me.get("displayName"))
    user = {
        "id": oid,
        "email": email,
        "nombre": me.get("displayName"),
        "tenant_id": tenant,
        "db_user_id": db_user.get("id"),
        "db_user_created_at": str(db_user.get("created_at")),
    }
    if user["db_user_id"]:
        await register_access(user["db_user_id"], client_ip, user_agent)

    expires_at = current + MAX_CACHE_SECONDS
    if isinstance(exp, (int, float)):
        expires_at = min(expires_at, float(exp))
    _prune(current)
    _cache[key] = (expires_at, user)
    return user
