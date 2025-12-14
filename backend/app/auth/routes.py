# auth/routes.py
"""
Rutas de autenticación OAuth con Microsoft Entra ID.
Implementa Authorization Code Flow con PKCE.
"""
import os
import secrets
import hashlib
import base64
from urllib.parse import urlencode
from typing import Optional
import httpx
from fastapi import APIRouter, Response, Cookie, HTTPException
from fastapi.responses import RedirectResponse
from dotenv import load_dotenv

load_dotenv()

router = APIRouter(prefix="/api/auth", tags=["auth"])

# Configuración de Entra ID
TENANT_ID = os.getenv("AZURE_TENANT_ID")
CLIENT_ID = os.getenv("AZURE_CLIENT_ID")
CLIENT_SECRET = os.getenv("AZURE_CLIENT_SECRET", "")  # Opcional para SPA
REDIRECT_URI = os.getenv("AZURE_REDIRECT_URI", "http://localhost:8000/api/auth/callback")
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost")

# Tenants permitidos (tu tenant personal + UTB)
# Agrega el tenant ID de UTB cuando lo tengas
ALLOWED_TENANTS = os.getenv("AZURE_ALLOWED_TENANTS", TENANT_ID).split(",")

# Single-tenant: solo permite usuarios de los tenants configurados
# Cambiar a "common" o "organizations" cuando se necesite multi-tenant
AUTHORITY = f"https://login.microsoftonline.com/{TENANT_ID}"
AUTHORIZE_URL = f"{AUTHORITY}/oauth2/v2.0/authorize"
TOKEN_URL = f"{AUTHORITY}/oauth2/v2.0/token"

# Almacén temporal de sesiones (en producción usar Redis o base de datos)
# Formato: {session_id: {user_info}}
sessions: dict = {}

# Almacén temporal de estados PKCE (para validar callbacks)
# Formato: {state: {code_verifier, ...}}
pending_auth: dict = {}


def generate_pkce_pair():
    """Genera code_verifier y code_challenge para PKCE."""
    code_verifier = secrets.token_urlsafe(32)
    code_challenge = base64.urlsafe_b64encode(
        hashlib.sha256(code_verifier.encode()).digest()
    ).decode().rstrip("=")
    return code_verifier, code_challenge


@router.get("/login")
def login():
    """
    Inicia el flujo de autenticación OAuth.
    Redirige al usuario a Microsoft para que inicie sesión.
    """
    if not TENANT_ID or not CLIENT_ID:
        raise HTTPException(status_code=500, detail="Configuración de Azure incompleta")
    
    # Generar PKCE
    code_verifier, code_challenge = generate_pkce_pair()
    
    # Generar state aleatorio para prevenir CSRF
    state = secrets.token_urlsafe(32)
    
    # Guardar para validar en el callback
    pending_auth[state] = {
        "code_verifier": code_verifier
    }
    
    # Construir URL de autorización
    params = {
        "client_id": CLIENT_ID,
        "response_type": "code",
        "redirect_uri": REDIRECT_URI,
        "scope": "openid profile email",
        "response_mode": "query",
        "state": state,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
    }
    
    auth_url = f"{AUTHORIZE_URL}?{urlencode(params)}"
    return RedirectResponse(url=auth_url)


@router.get("/callback")
async def callback(code: str = None, state: str = None, error: str = None, error_description: str = None):
    """
    Callback de Microsoft después del login.
    Intercambia el código por tokens y crea la sesión.
    """
    # Manejar errores de Microsoft
    if error:
        print(f"Error de OAuth: {error} - {error_description}")
        return RedirectResponse(url=f"{FRONTEND_URL}?error={error}")
    
    if not code or not state:
        raise HTTPException(status_code=400, detail="Faltan parámetros code o state")
    
    # Validar state (previene CSRF)
    if state not in pending_auth:
        raise HTTPException(status_code=400, detail="State inválido o expirado")
    
    code_verifier = pending_auth.pop(state)["code_verifier"]
    
    # Intercambiar código por tokens
    token_data = {
        "client_id": CLIENT_ID,
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": REDIRECT_URI,
        "code_verifier": code_verifier,
    }
    
    # Si hay client_secret (aplicación confidencial), agregarlo
    if CLIENT_SECRET:
        token_data["client_secret"] = CLIENT_SECRET
    
    async with httpx.AsyncClient() as client:
        response = await client.post(TOKEN_URL, data=token_data)
        
        if response.status_code != 200:
            print(f"Error al obtener token: {response.text}")
            return RedirectResponse(url=f"{FRONTEND_URL}?error=token_error")
        
        tokens = response.json()
    
    # Decodificar ID token para obtener info del usuario
    id_token = tokens.get("id_token")
    if not id_token:
        return RedirectResponse(url=f"{FRONTEND_URL}?error=no_id_token")
    
    # Decodificar sin verificar (ya confiamos porque viene directo de Microsoft)
    from jose import jwt
    try:
        # Decodificar sin verificar firma (el token viene directo de Microsoft vía HTTPS)
        user_info = jwt.get_unverified_claims(id_token)
    except Exception as e:
        print(f"Error decodificando token: {e}")
        return RedirectResponse(url=f"{FRONTEND_URL}?error=invalid_token")
    
    # Validar que el tenant esté permitido
    user_tenant = user_info.get("tid")
    if user_tenant not in ALLOWED_TENANTS:
        print(f"Tenant no autorizado: {user_tenant}")
        return RedirectResponse(url=f"{FRONTEND_URL}?error=tenant_not_allowed")
    
    # Crear sesión
    session_id = secrets.token_urlsafe(32)
    sessions[session_id] = {
        "id": user_info.get("oid"),  # Object ID
        "email": user_info.get("preferred_username") or user_info.get("email"),
        "nombre": user_info.get("name"),
        "tenant_id": user_info.get("tid"),
    }
    
    # Redirigir al frontend con cookie de sesión
    response = RedirectResponse(url=FRONTEND_URL)
    response.set_cookie(
        key="session_id",
        value=session_id,
        httponly=True,
        secure=False,  # En producción: True (requiere HTTPS)
        samesite="lax",
        max_age=86400 * 7,  # 7 días
    )
    
    return response


@router.get("/me")
def get_me(session_id: Optional[str] = Cookie(default=None)):
    """
    Retorna información del usuario de la sesión actual.
    """
    if not session_id or session_id not in sessions:
        raise HTTPException(status_code=401, detail="No autenticado")
    
    user = sessions[session_id]
    return {
        "id": user["id"],
        "email": user["email"],
        "nombre": user["nombre"],
        "authenticated": True
    }


@router.post("/logout")
def logout(session_id: Optional[str] = Cookie(default=None)):
    """
    Cierra la sesión del usuario y retorna URL para cerrar sesión en Microsoft.
    """
    if session_id and session_id in sessions:
        del sessions[session_id]
    
    # URL de logout de Microsoft Entra ID
    ms_logout_url = f"{AUTHORITY}/oauth2/v2.0/logout?post_logout_redirect_uri={FRONTEND_URL}"
    
    response = Response(
        content=f'{{"message": "Sesión cerrada", "microsoft_logout_url": "{ms_logout_url}"}}', 
        media_type="application/json"
    )
    response.delete_cookie("session_id")
    return response
