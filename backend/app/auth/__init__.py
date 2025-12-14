# auth/__init__.py
"""
Módulo de autenticación con Microsoft Entra ID.
"""
from .dependencies import get_current_user, get_current_user_optional
from .entra_id import verify_token

__all__ = ["get_current_user", "get_current_user_optional", "verify_token"]
