"""
AgentCore Runtime entry — official Strands / bedrock-agentcore pattern.

Imports the existing FastAPI app from app.main and exposes AgentCore
entrypoints. Do not deploy yet; this file is deployment-ready only.

Local test:
  uvicorn agentcore_entry:application --host 0.0.0.0 --port 8080
  # or: python agentcore_entry.py
"""

from __future__ import annotations

import json
from typing import Any

from bedrock_agentcore.runtime import BedrockAgentCoreApp

from app.core.agent import run_task
from app.core.auth import AuthError, verify_supabase_jwt

# Official AgentCore runtime wrapper (SDK Integration pattern).
agentcore_app = BedrockAgentCoreApp()


def _user_id_from_payload(payload: dict[str, Any], headers: dict | None = None) -> str:
    """
    Prefer Authorization header when present; else JWT inside payload.
    AgentCore invoke may not forward custom headers the same way as uvicorn.
    """
    auth = None
    if headers:
        auth = headers.get("authorization") or headers.get("Authorization")
    if not auth:
        token = payload.get("jwt") or payload.get("token")
        if token:
            auth = f"Bearer {token}"
    return verify_supabase_jwt(auth)


@agentcore_app.entrypoint
async def invoke(payload: dict[str, Any]) -> dict[str, Any]:
    """
    AgentCore /invocations handler.

    Payload:
      {
        "prompt": "..." | "task": "...",
        "mode": "chat|exam_plan|recover|monitor|progress",
        "user_id": optional (ignored if JWT present),
        "jwt": optional Supabase access token
      }
    """
    headers: dict | None = payload.get("_headers")
    task = (payload.get("prompt") or payload.get("task") or "").strip()
    mode = payload.get("mode") or "chat"
    if not task:
        return {"output": {"error": "prompt or task is required"}}

    try:
        user_id = _user_id_from_payload(payload, headers)
    except AuthError as e:
        return {"output": {"error": f"unauthorized: {e}"}}

    result = await run_task(user_id, task, mode=mode)
    return {
        "output": {
            "summary": result.get("summary"),
            "mode": mode,
            "needsConfirmation": bool(result.get("needsConfirmation")),
            "tool_trace": result.get("tool_trace") or [],
        }
    }


if __name__ == "__main__":
    # Serves /invocations + /ping on 8080 per AgentCore Runtime requirements.
    agentcore_app.run()
