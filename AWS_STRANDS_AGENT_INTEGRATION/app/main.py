"""FastAPI entry — Flutter + AgentCore-compatible HTTP surface."""

from __future__ import annotations

import logging
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from app.core.agent import run_task
from app.core.auth import AuthError, verify_supabase_jwt
from app.core.monitor import run_daily_monitor
from app.config import get_settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("strands_api")

app = FastAPI(
    title="StudyLifeAgent — Strands",
    version="0.1.0",
    description="Official Strands Agents SDK backend for Smart Revision Tracker",
)

# Flutter may call from any origin (Android WebView / custom tab / web debug).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


class InvokeRequest(BaseModel):
    task: str = Field(..., min_length=1, max_length=8000)
    mode: str = Field(default="chat", pattern="^(chat|exam_plan|recover|monitor|progress)$")


class InvokeResponse(BaseModel):
    summary: str
    mode: str
    needsConfirmation: bool
    tool_trace: list[str] = Field(default_factory=list)


def _user_id(authorization: str | None = Header(default=None)) -> str:
    try:
        return verify_supabase_jwt(authorization)
    except AuthError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e


@app.get("/health")
def health() -> dict[str, Any]:
    s = get_settings()
    return {"ok": True, "env": s.app_env, "sdk": "strands-agents"}


@app.get("/ping")
def ping() -> dict[str, str]:
    """AgentCore Runtime required health endpoint."""
    return {"status": "healthy"}


@app.post("/v1/agent/invoke", response_model=InvokeResponse)
async def invoke(
    body: InvokeRequest,
    user_id: str = Depends(_user_id),
) -> InvokeResponse:
    try:
        if body.mode == "monitor":
            mon = await run_daily_monitor(user_id)
            return InvokeResponse(
                summary=mon.get("summary") or "NO_ACTION",
                mode=body.mode,
                needsConfirmation=bool(mon.get("notify")),
            )
        out = await run_task(user_id, body.task, mode=body.mode)
        return InvokeResponse(
            summary=out.get("summary") or "",
            mode=body.mode,
            needsConfirmation=bool(out.get("needsConfirmation")),
            tool_trace=out.get("tool_trace") or [],
        )
    except Exception as e:  # noqa: BLE001
        logger.exception("agent invoke failed")
        raise HTTPException(status_code=500, detail=f"Agent failed: {e}") from e


@app.post("/invocations")
async def invocations(request: Request, body: dict[str, Any]) -> dict[str, Any]:
    """
    AgentCore Runtime REQUIRED POST endpoint.

    Accepts the same JSON as /v1/agent/invoke but also supports
    AgentCore-style {"input": {"prompt": "..."}} and JWT in payload.
    """
    auth = request.headers.get("authorization")
    payload = dict(body or {})
    if "input" in payload and isinstance(payload["input"], dict):
        inner = payload["input"]
        payload.setdefault("prompt", inner.get("prompt") or inner.get("task") or "")
        payload.setdefault("mode", inner.get("mode") or "chat")
        payload.setdefault("jwt", inner.get("jwt"))
    if not payload.get("prompt") and payload.get("task"):
        payload["prompt"] = payload["task"]

    task = (payload.get("prompt") or "").strip()
    if not task:
        raise HTTPException(status_code=400, detail="prompt is required")
    mode = payload.get("mode") or "chat"

    token = auth
    if not token:
        jwt = payload.get("jwt") or payload.get("token")
        if jwt:
            token = f"Bearer {jwt}"
    try:
        user_id = verify_supabase_jwt(token)
    except AuthError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e

    try:
        if mode == "monitor":
            mon = await run_daily_monitor(user_id)
            return {"output": {"summary": mon.get("summary") or "NO_ACTION", "mode": mode,
                               "needsConfirmation": bool(mon.get("notify"))}}
        out = await run_task(user_id, task, mode=mode)
        return {
            "output": {
                "summary": out.get("summary") or "",
                "mode": mode,
                "needsConfirmation": bool(out.get("needsConfirmation")),
                "tool_trace": out.get("tool_trace") or [],
            }
        }
    except Exception as e:  # noqa: BLE001
        logger.exception("invocations failed")
        raise HTTPException(status_code=500, detail=f"Agent failed: {e}") from e


@app.post("/v1/monitor/run")
async def monitor_endpoint(user_id: str = Depends(_user_id)) -> dict[str, Any]:
    """For EventBridge / cron / Flutter WorkManager."""
    return await run_daily_monitor(user_id)
