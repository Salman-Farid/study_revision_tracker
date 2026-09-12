"""Class / daily routine tools — same tables as Flutter RoutineRepository."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from strands import tool

from app.core.supabase_client import get_supabase


def _now() -> datetime:
    return datetime.now(timezone.utc)


@tool
def register_class_routine(
    user_id: str,
    subject_name: str,
    start_time: str,
    duration_minutes: int,
    dates: list | None = None,
    recurring: bool = False,
    recurring_days: list | None = None,
    location: str | None = None,
    notes: str | None = None,
) -> dict:
    """
    Create a class routine. start_time ISO or 'HH:MM'.
    dates: ['YYYY-MM-DD', ...]; recurring_days: 1=Mon … 7=Sun.
    """
    sb = get_supabase()
    now = _now()
    if len(start_time) == 5:
        start_iso = f"{now.strftime('%Y-%m-%d')}T{start_time}:00{now.strftime('%z')}"
    else:
        start_iso = start_time
    rid = str(uuid.uuid4())
    sb.table("class_routines").insert({
        "id": rid,
        "user_id": user_id,
        "subject_name": subject_name.strip(),
        "start_time": start_iso,
        "duration_minutes": int(duration_minutes),
        "dates": dates or [],
        "recurring": bool(recurring or recurring_days),
        "recurring_days": recurring_days or [],
        "location": location,
        "notes": notes,
        "created_at": now.isoformat(),
        "updated_at": now.isoformat(),
    }).execute()
    return {"success": True, "id": rid}


@tool
def register_daily_routine(user_id: str, date_iso: str, items: list) -> dict:
    """
    Replace the daily routine for one date.
    items: [{time:'HH:MM', subject, topic, type, durationMinutes, notes?}]
    type: study|first_read|revision|review|recall|question_practice|class|break|meal|nap
    Validates study subjects exist in the DB (same rule as Flutter).
    """
    sb = get_supabase()
    subjects = (
        sb.table("subjects").select("name").eq("user_id", user_id).execute().data or []
    )
    valid = {s["name"].lower() for s in subjects}
    allowed_non_db = {"break", "breakfast", "lunch", "dinner", "power nap"}
    study_types = {"study", "first_read", "revision", "review", "question_practice"}

    for it in items:
        t = (it.get("type") or "study").lower()
        subj = (it.get("subject") or "").strip()
        if t in study_types and subj and subj.lower() not in valid and subj.lower() not in allowed_non_db:
            return {
                "success": False,
                "error": f"Subject '{subj}' not in database. Valid: {sorted(valid)}",
            }

    now = _now()
    rid = str(uuid.uuid4())
    sb.table("daily_routines").delete().eq("user_id", user_id).eq("date", date_iso).execute()
    sb.table("daily_routines").insert({
        "id": rid,
        "user_id": user_id,
        "date": date_iso,
        "items": items,
        "created_at": now.isoformat(),
        "updated_at": now.isoformat(),
    }).execute()
    return {"success": True, "id": rid, "blocks": len(items)}


@tool
def delete_daily_routine(user_id: str, date_iso: str) -> dict:
    """Delete the entire daily routine for one date."""
    sb = get_supabase()
    sb.table("daily_routines").delete().eq("user_id", user_id).eq("date", date_iso).execute()
    return {"success": True, "date": date_iso}
