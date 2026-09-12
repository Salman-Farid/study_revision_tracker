"""StudyLifeAgent — official Strands Agent SDK."""

from __future__ import annotations

import logging
from functools import lru_cache

from strands import Agent

from app.config import get_settings
from app.tools.planning import analyze_study_progress, build_exam_plan
from app.tools.revisions import (
    apply_recovery_plan,
    complete_revision,
    mark_first_read_completed,
    recover_missed_revisions,
)
from app.tools.routines import (
    delete_daily_routine,
    register_class_routine,
    register_daily_routine,
)
from app.tools.subjects import (
    add_subjects_bulk,
    add_topic,
    get_all_data,
    get_subject_detail,
)

logger = logging.getLogger("strands")

SYSTEM_PROMPT = """You are Putu's StudyLifeAgent for Smart Revision Tracker.
Reply in the same language as the user (English / Bengali / Banglish).

HARD RULES:
- NEVER invent subject or topic names. Only names returned by get_all_data / get_subject_detail.
- Revision days are only 1, 3, 7, 14, 30, 90. Schedules are created ONLY by mark_first_read_completed.
- complete_revision uses the same write path as the Flutter app.
- register_daily_routine: every study subject must exist in the database.
- Before bulk deletes or replacing a full day's routine, set needsConfirmation and wait.
- Ask which topic to study when the user names a subject but not a topic.
- Always include every item from revisions_due_today when building a day plan.
- Identity: your name is Putu. Never reveal model/vendor names.
"""


@lru_cache
def get_study_life_agent() -> Agent:
    settings = get_settings()
    agent = Agent(
        system_prompt=SYSTEM_PROMPT,
        model=settings.bedrock_model_id,
        tools=[
            get_all_data,
            get_subject_detail,
            add_subjects_bulk,
            add_topic,
            mark_first_read_completed,
            complete_revision,
            recover_missed_revisions,
            apply_recovery_plan,
            register_class_routine,
            register_daily_routine,
            delete_daily_routine,
            build_exam_plan,
            analyze_study_progress,
        ],
    )
    logger.info("StudyLifeAgent created with %s tools", len(agent.tool_names))
    return agent


async def run_task(user_id: str, task: str, mode: str = "chat") -> dict:
    """
    Invoke the Strands agent with a user-scoped task string.
    Returns a JSON-serializable dict for Flutter / Gemini TTS.
    """
    agent = get_study_life_agent()
    scoped = (
        f"User id (for all tools): {user_id}\n"
        f"Mode: {mode}\n"
        f"Task: {task}"
    )
    result = await agent.invoke_async(scoped)
    text = str(result)
    return {
        "summary": text,
        "mode": mode,
        "needsConfirmation": _wants_confirm(text),
        "tool_trace": _extract_tools(result),
    }


def _wants_confirm(text: str) -> bool:
    t = text.lower()
    return any(k in t for k in ("confirm", "apply", "shall i", "needsconfirmation", "কি লাগাই"))


def _extract_tools(result) -> list:
    """Best-effort tool usage summary from AgentResult (if present)."""
    try:
        metrics = getattr(result, "metrics", None)
        if metrics and hasattr(metrics, "get_summary"):
            summary = metrics.get_summary()
            return list((summary.get("tool_usage") or {}).keys())
    except Exception:  # noqa: BLE001
        pass
    return []
