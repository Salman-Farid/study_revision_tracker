"""Daily monitor — run via cron/Lambda or WorkManager HTTP call.

Only surfaces decisions the user must make; no notification spam.
"""

from __future__ import annotations

from datetime import datetime, timezone

from app.core.agent import run_task
from app.core.supabase_client import get_supabase

MONITOR_TASK = (
    "Daily monitor (read-only unless a decision is required). "
    "1) List overdue revisions. 2) If tomorrow has class_routines but no daily_routine, "
    "propose a plan. 3) If a topic's first_read is still incomplete for 7+ days, mention it. "
    "If nothing needs a decision, reply ONLY: NO_ACTION."
)


async def run_daily_monitor(user_id: str) -> dict:
    result = await run_task(user_id, MONITOR_TASK, mode="monitor")
    summary = (result.get("summary") or "").strip()
    if summary.upper().startswith("NO_ACTION") or not summary:
        return {"notify": False, "user_id": user_id}
    # Persist alert so Flutter can pick it up on next open (optional)
    try:
        sb = get_supabase()
        sb.table("agent_alerts").insert({
            "user_id": user_id,
            "kind": "daily_monitor",
            "message": summary[:2000],
            "created_at": datetime.now(timezone.utc).isoformat(),
            "read": False,
        }).execute()
    except Exception:  # noqa: BLE001 — table may not exist yet
        pass
    return {"notify": True, "user_id": user_id, "summary": summary}
