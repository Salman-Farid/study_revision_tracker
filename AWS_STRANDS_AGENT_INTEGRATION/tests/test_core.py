"""Smoke tests — require live Supabase + model creds; skip if missing."""

from __future__ import annotations

import os

import pytest

pytest.importorskip("strands")

from app.config import get_settings  # noqa: E402
from app.core.auth import AuthError, verify_supabase_jwt  # noqa: E402


def test_settings_revision_days_match_flutter():
    assert list(get_settings().revision_days) == [1, 3, 7, 14, 30, 90]


def test_jwt_missing_header():
    with pytest.raises(AuthError):
        verify_supabase_jwt(None)


def test_jwt_invalid():
    with pytest.raises(AuthError):
        verify_supabase_jwt("Bearer not-a-jwt")


@pytest.mark.skipif(
    not os.getenv("SUPABASE_URL") or not os.getenv("SUPABASE_SERVICE_ROLE_KEY"),
    reason="Supabase env not set",
)
def test_supabase_client():
    from app.core.supabase_client import get_supabase

    assert get_supabase() is not None
