"""Revision tools — mirror Flutter completeRevision / createRevisionSchedules."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from strands import tool

from app.config import get_settings
from app.core.supabase_client import get_supabase


def _now() -> datetime:
    return datetime.now(timezone.utc)


@tool
def mark_first_read_completed(user_id: str, subject_name: str, topic_name: str) -> dict:
    """
    Mark first read done and create 6 revision schedules (day 1,3,7,14,30,90) from today.
    This is the ONLY path that creates revision_schedules (same as Flutter).
    """
    sb = get_supabase()
    topics = (
        sb.table("topics")
        .select("id,subject_id,name,first_read_completed")
        .eq("user_id", user_id)
        .ilike("name", topic_name)
        .execute().data or []
    )
    # Prefer topic under the named subject
    topic = None
    if topics:
        subjects = (
            sb.table("subjects").select("id").eq("user_id", user_id)
            .ilike("name", subject_name).execute().data or []
        )
        sid = subjects[0]["id"] if subjects else None
        topic = next((t for t in topics if t["subject_id"] == sid), topics[0])
    if not topic:
        return {"success": False, "error": f"Topic '{topic_name}' not found"}
    if topic.get("first_read_completed"):
        return {"success": True, "already_completed": True, "topic_id": topic["id"]}

    now = _now()
    sb.table("topics").update({
        "first_read_completed": True,
        "updated_at": now.isoformat(),
    }).eq("id", topic["id"]).execute()

    days = get_settings().revision_days
    rows = []
    for d in days:
        rows.append({
            "id": str(uuid.uuid4()),
            "user_id": user_id,
            "topic_id": topic["id"],
            "subject_id": topic["subject_id"],
            "scheduled_date": (now + timedelta(days=d)).isoformat(),
            "day_number": d,
            "status": "pending",
        })
    sb.table("revision_schedules").insert(rows).execute()
    return {
        "success": True,
        "topic_id": topic["id"],
        "scheduled_days": list(days),
        "message": "First read completed; 6 revisions scheduled from today.",
    }


@tool
def complete_revision(user_id: str, schedule_id: str, topic_id: str) -> dict:
    """
    Complete one revision day (single source of truth with Flutter completeRevision):
    revision_schedules.status=completed and topics.total_revisions += 1.
    """
    sb = get_supabase()
    now = _now()
    sb.table("revision_schedules").update({"status": "completed"}).eq(
        "id", schedule_id
    ).eq("user_id", user_id).execute()

    topic = (
        sb.table("topics").select("total_revisions")
        .eq("id", topic_id).eq("user_id", user_id).execute().data or []
    )
    if topic:
        nxt = int(topic[0].get("total_revisions") or 0) + 1
        sb.table("topics").update({
            "total_revisions": nxt,
            "last_revised_at": now.isoformat(),
            "updated_at": now.isoformat(),
        }).eq("id", topic_id).execute()
    return {"success": True, "schedule_id": schedule_id, "topic_id": topic_id}


@tool
def recover_missed_revisions(user_id: str) -> dict:
    """
    List overdue pending revisions and propose a recovery order.
    Does NOT write — call apply_recovery_plan after user confirms.
    """
    sb = get_supabase()
    today = _now().strftime("%Y-%m-%d")
    rows = (
        sb.table("revision_schedules")
        .select("id,topic_id,subject_id,day_number,scheduled_date")
        .eq("user_id", user_id)
        .eq("status", "pending")
        .lt("scheduled_date", today)
        .order("scheduled_date")
        .execute().data or []
    )
    topic_ids = {r["topic_id"] for r in rows}
    subject_ids = {r["subject_id"] for r in rows}
    topics = (
        sb.table("topics").select("id,name").in_("id", list(topic_ids)).execute().data
        if topic_ids else []
    )
    subjects = (
        sb.table("subjects").select("id,name").in_("id", list(subject_ids)).execute().data
        if subject_ids else []
    )
    tmap = {t["id"]: t["name"] for t in topics}
    smap = {s["id"]: s["name"] for s in subjects}
    plan = []
    for r in rows:
        plan.append({
            "schedule_id": r["id"],
            "topic_id": r["topic_id"],
            "day_number": r["day_number"],
            "topic": tmap.get(r["topic_id"], ""),
            "subject": smap.get(r["subject_id"], ""),
            "original_date": str(r["scheduled_date"])[:10],
        })
    return {
        "success": True,
        "overdue_count": len(plan),
        "recovery_plan": plan,
        "needsConfirmation": True,
        "question": f"You have {len(plan)} missed revisions. Reschedule them into the next free slots?",
    }


@tool
def apply_recovery_plan(user_id: str, schedule_ids: list) -> dict:
    """After user confirms: push each overdue schedule_date to tomorrow (or later)."""
    sb = get_supabase()
    base = _now() + timedelta(days=1)
    updated = []
    for i, sid in enumerate(schedule_ids):
        new_date = (base + timedelta(days=i)).isoformat()
        sb.table("revision_schedules").update({
            "scheduled_date": new_date,
        }).eq("id", sid).eq("user_id", user_id).execute()
        updated.append({"schedule_id": sid, "new_date": new_date})
    return {"success": True, "updated": updated}
