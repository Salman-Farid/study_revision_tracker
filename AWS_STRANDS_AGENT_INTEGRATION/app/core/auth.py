"""Verify Supabase JWT; user_id comes from the token only."""

from __future__ import annotations

import jwt

from app.config import get_settings


class AuthError(Exception):
    pass


def verify_supabase_jwt(authorization_header: str | None) -> str:
    if not authorization_header or not authorization_header.lower().startswith("bearer "):
        raise AuthError("Missing Bearer token")
    token = authorization_header.split(" ", 1)[1].strip()
    secret = get_settings().supabase_jwt_secret
    if not secret:
        raise AuthError("SUPABASE_JWT_SECRET not configured")
    try:
        payload = jwt.decode(
            token,
            secret,
            algorithms=["HS256"],
            options={"require": ["exp"]},
        )
    except jwt.PyJWTError as e:
        raise AuthError(f"Invalid token: {e}") from e

    user_id = payload.get("sub") or payload.get("user_id")
    if not user_id:
        raise AuthError("Token missing sub/user_id")
    return str(user_id)
