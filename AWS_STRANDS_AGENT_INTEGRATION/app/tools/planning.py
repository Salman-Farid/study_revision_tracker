"""Exam plan + weekly analysis — planning tools only; apply via register_daily_routine."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from strands import tool

from app.config import get_settings
from app.core.supabase_client import get_supabase


def _now() -> datetime:
    return datetime.now(timezone.utc)


@tool
def build_exam_plan(user_id: str, exam_date: str, hours_per_day: int = 6) -> dict:
    """
    Propose a multi-day study plan until exam_date using real subjects and
    first-read topics only. Returns proposed daily blocks — does NOT insert.
    After user confirms, call register_daily_routine per day.
    """
    sb = get_supabase()
    exam = datetime.fromisoformat(exam_date).date()
    today = _now().date()
    if exam <= today:
        return {"success": False, "error": "exam_date must be in the future"}

    subjects = (
        sb.table("subjects").select("id,name")
        .eq("user_id", user_id).eq("is_archived", False).execute().data or []
    )
    if not subjects:
        return {"success": False, "error": "No subjects in database"}

    topics = (
        sb.table("topics")
        .select("id,subject_id,name,first_read_completed")
        .eq("user_id", user_id).execute().data or []
    )
    first_read = [
        t for t in topics if not t.get("first_read_completed")
    ]
    by_subject: dict[str, list] = {}
    for t in first_read:
        by_subject.setdefault(t["subject_id"], []).append(t["name"])

    days_left = (exam - today).days
    blocks_per_day = max(1, int(hours_per_day * 60 / 50))  # 50-min study blocks
    plan = []
    sid_list = list(by_subject.keys()) or [s["id"] for s in subjects]
    idx = 0
    for d in range(days_left):
        day = today + timedelta(days=d)
        day_items = []
        start_min = 9 * 60  # 09:00
        for b in range(blocks_per_day):
            sid = sid_list[idx % len(sid_list)]
            name = next((s["name"] for s in subjects if s["id"] == sid), "Study")
            tlist = by_subject.get(sid) or []
            topic = tlist[idx % len(tlist)] if tlist else "—"
            h, m = divmod(start_min, 60)
            day_items.append({
                "time": f"{h:02d}:{m:02d}",
                "subject": name,
                "topic": topic,
                "type": "study",
                "durationMinutes": 50,
            })
            start_min += 60  # + break
            idx += 1
        plan.append({"date": day.isoformat(), "items": day_items})

    return {
        "success": True,
        "exam_date": exam.isoformat(),
        "days": days_left,
        "plan": plan,
        "needsConfirmation": True,
        "question": f"Apply this {days_left}-day plan to your daily routines?",
    }


@tool
def analyze_study_progress(user_id: str, days: int = 7) -> dict:
    """
    Weekly analysis: completion = completed revisions / (topics × 6),
    sessions this week, subjects needing attention.
    """
    sb = get_supabase()
    topics = (
        sb.table("topics").select("id,subject_id,name,total_revisions,first_read_completed")
        .eq("user_id", user_id).execute().data or []
    )
    completed = (
        sb.table("revision_schedules").select("id")
        .eq("user_id", user_id).eq("status", "completed").execute().data or []
    )
    planned = len(topics) * len(get_settings().revision_days)
    rate = (len(completed) / planned) if planned else 0.0

    since = (_now() - timedelta(days=days)).isoformat()
    sessions = (
        sb.table("revision_sessions").select("id")
        .eq("user_id", user_id).gte("started_at", since).execute().data or []
    )
    subjects = (
        sb.table("subjects").select("id,name").eq("user_id", user_id).execute().data or []
    )
    smap = {s["id"]: s["name"] for s in subjects}
    weak = []
    for s in subjects:
        st = [t for t in topics if t["subject_id"] == s["id"]]
        if not st:
            continue
        done = sum(int(t.get("total_revisions") or 0) for t in st)
        weak.append({
            "subject": s["name"],
            "topics": len(st),
            "revisions_done": done,
            "revisions_planned": len(st) * len(get_settings().revision_days),
        })
    weak.sort(key=lambda x: x["revisions_done"])

    return {
        "success": True,
        "completion_rate": round(rate, 4),
        "completed_revisions": len(completed),
        "planned_revisions": planned,
        "topics": len(topics),
        "sessions_last_days": len(sessions),
        "subject_progress": weak,
        "weakest_subjects": weak[:3],
    }
