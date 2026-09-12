"""Subject / topic tools — same tables as Flutter SupabaseService."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from strands import tool

from app.core.supabase_client import get_supabase


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@tool
def get_all_data(user_id: str) -> dict:
    """
    Compact snapshot of the user's study data for planning.
    Returns subjects, pending revision counts, today's classes, and daily routine items.
    """
    sb = get_supabase()
    subjects = (
        sb.table("subjects")
        .select("id,name,color_hex,total_topics,image_url")
        .eq("user_id", user_id)
        .eq("is_archived", False)
        .execute()
        .data
        or []
    )
    topics = (
        sb.table("topics")
        .select("id,subject_id,name,first_read_completed,total_revisions")
        .eq("user_id", user_id)
        .execute()
        .data
        or []
    )
    today = datetime.now().strftime("%Y-%m-%d")
    tomorrow = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    tomorrow_s = tomorrow.fromordinal(tomorrow.toordinal() + 1).strftime("%Y-%m-%d")

    pending = (
        sb.table("revision_schedules")
        .select("id,topic_id,subject_id,scheduled_date,day_number,status")
        .eq("user_id", user_id)
        .eq("status", "pending")
        .execute()
        .data
        or []
    )
    overdue = [r for r in pending if str(r["scheduled_date"])[:10] < today]
    due_today = [r for r in pending if str(r["scheduled_date"])[:10] == today]

    classes = (
        sb.table("class_routines")
        .select("id,subject_name,start_time,duration_minutes,dates,recurring,recurring_days,location")
        .eq("user_id", user_id)
        .execute()
        .data
        or []
    )
    daily = (
        sb.table("daily_routines")
        .select("id,date,items")
        .eq("user_id", user_id)
        .eq("date", today)
        .execute()
        .data
        or []
    )

    return {
        "subjects": subjects,
        "topics_count": len(topics),
        "topics": topics,
        "overdue_count": len(overdue),
        "overdue": overdue,
        "revisions_due_today": due_today,
        "class_routines_today": [
            c for c in classes
            if _class_matches_day(c, datetime.now())
        ],
        "daily_routines": daily,
        "today": today,
        "tomorrow": tomorrow_s,
    }


def _class_matches_day(cls: dict, day: datetime) -> bool:
    date_str = day.strftime("%Y-%m-%d")
    dates = cls.get("dates") or []
    if any(str(d) == date_str or str(d).startswith(date_str) for d in dates):
        return True
    return day.weekday() + 1 in (cls.get("recurring_days") or [])


@tool
def get_subject_detail(user_id: str, subject_name: str) -> dict:
    """Topics and revision status for one subject (exact DB name)."""
    sb = get_supabase()
    subjects = (
        sb.table("subjects").select("id,name")
        .eq("user_id", user_id).ilike("name", subject_name).execute().data or []
    )
    if not subjects:
        return {"success": False, "error": f"Subject '{subject_name}' not found"}
    subject = subjects[0]
    topics = (
        sb.table("topics")
        .select("id,name,first_read_completed,total_revisions")
        .eq("subject_id", subject["id"])
        .execute().data or []
    )
    schedules = (
        sb.table("revision_schedules")
        .select("id,topic_id,day_number,scheduled_date,status")
        .eq("subject_id", subject["id"])
        .execute().data or []
    )
    return {
        "success": True,
        "subject": subject,
        "topics": topics,
        "schedules": schedules,
    }


@tool
def add_subjects_bulk(user_id: str, subjects: list) -> dict:
    """
    Create subjects (and optional topics). Topics stay in first read —
    no revision schedules until mark_first_read_completed.
    Each item: {name: str, topics?: [str], color?: str}
    """
    sb = get_supabase()
    created, failed = [], []
    for item in subjects:
        name = (item.get("name") or "").strip()
        if not name:
            failed.append({"name": "", "error": "empty name"})
            continue
        try:
            existing = (
                sb.table("subjects").select("id")
                .eq("user_id", user_id).ilike("name", name).execute().data or []
            )
            if existing:
                subject_id = existing[0]["id"]
            else:
                subject_id = str(uuid.uuid4())
                sb.table("subjects").insert({
                    "id": subject_id,
                    "user_id": user_id,
                    "name": name,
                    "color_hex": item.get("color") or "#87CEEB",
                    "is_archived": False,
                    "total_topics": 0,
                }).execute()
            for tname in item.get("topics") or []:
                tname = (tname or "").strip()
                if not tname:
                    continue
                tid = str(uuid.uuid4())
                sb.table("topics").insert({
                    "id": tid,
                    "user_id": user_id,
                    "subject_id": subject_id,
                    "name": tname,
                    "first_read_completed": False,
                    "total_revisions": 0,
                    "created_at": _now_iso(),
                    "updated_at": _now_iso(),
                }).execute()
            created.append({"name": name, "subject_id": subject_id})
        except Exception as e:  # noqa: BLE001
            failed.append({"name": name, "error": str(e)})
    return {"success": not failed, "created": created, "failed": failed}


@tool
def add_topic(user_id: str, subject_name: str, topic_name: str) -> dict:
    """Add one topic under an existing subject. No revision dates until first-read is done."""
    sb = get_supabase()
    subjects = (
        sb.table("subjects").select("id")
        .eq("user_id", user_id).ilike("name", subject_name).execute().data or []
    )
    if not subjects:
        return {"success": False, "error": f"Subject '{subject_name}' not found"}
    subject_id = subjects[0]["id"]
    tid = str(uuid.uuid4())
    sb.table("topics").insert({
        "id": tid,
        "user_id": user_id,
        "subject_id": subject_id,
        "name": topic_name.strip(),
        "first_read_completed": False,
        "total_revisions": 0,
        "created_at": _now_iso(),
        "updated_at": _now_iso(),
    }).execute()
    return {"success": True, "topic_id": tid, "message": f"Topic '{topic_name}' added to first read."}
