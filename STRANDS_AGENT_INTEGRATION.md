# STRANDS_AGENT_INTEGRATION.md

**Study Revision Tracker — official Strands Agents SDK (Python backend)**

> **Implementation lives in:** [`AWS_STRANDS_AGENT_INTEGRATION/`](./AWS_STRANDS_AGENT_INTEGRATION/)  
> Isolated folder — **no Flutter/Dart code** inside it.

> **Gemini Live = voice only** (STT + TTS).  
> **Strands Agent (Python) = all tool calls & agentic planning.**  
> Do **not** reimplement Strands inside Dart. Official SDKs: Python [`strands-agents`](https://pypi.org/project/strands-agents/) · TypeScript [`@strands-agents/sdk`](https://www.npmjs.com/package/@strands-agents/sdk). There is **no** official Dart package.

---

## 1. Architecture (required for “Build with Strands Agents”)

```text
User speaks
   ↓
Gemini Live (STT)                    lib/gemini_3_flash_live_voice_chatbot/
   ↓  user text
Flutter
   ↓  HTTPS POST /v1/agent/invoke  { task, mode, jwt }
Strands Agent backend (Python)       strands-agents SDK
   Agent(tools=[…], system_prompt=…)
   ↓
Tools (thin wrappers around same Supabase tables)
   ├─ add_topic / add_subjects_bulk
   ├─ mark_first_read_completed
   ├─ complete_revision
   ├─ register_class_routine / register_daily_routine
   ├─ build_exam_plan
   ├─ recover_missed_revisions
   └─ analyze_study_progress
   ↓
Supabase (same RLS tables the Flutter app already uses)
   ↓
Agent final reply (JSON: summary, plan, needsConfirmation)
   ↓
Flutter → Gemini Live TTS → User hears answer
   ↓
App UI already live via Supabase realtime + NotificationService + widgets
```

**One data source:** Postgres via existing `SupabaseService` / repos. Strands tools must **not** invent a second revision engine.

---

## 2. What exists in the Flutter app (reuse)

| Area | Path | Role after integration |
|------|------|-------------------------|
| Voice WS | `gemini_3_flash_live_voice_chatbot/services/gemini_live_service.dart` | STT/TTS only — pass **empty** `tools` to `startSession` |
| Gemini tool JSON + handlers | `…/voice_assistant/voice_assistant_controller.dart` (`_tools`, `_handleFunctionCall`, `_addTopic`, `_registerDailyRoutine`, …) | **Delete / thin out** after Strands owns tools |
| DB | `lib/app/data/services/supabase_service.dart` | Source of truth (Flutter UI + Strands tools) |
| Repos | `revision_repository.dart`, `topic_repository.dart`, `routine_repository.dart`, `subject_repository.dart` | Same operations mirrored in Python tools |
| Spacing | `AppConstants.revisionDays = [1,3,7,14,30,90]` | Hard-code the same list in the Strands system prompt / tools |
| Side effects | `notification_service.dart`, `widget_data_service.dart` | Triggered by Flutter realtime / WorkManager after DB writes — Strands only writes Supabase |

---

## 3. Backend (Python — real `strands-agents`)

### Install

```bash
python -m venv .venv && source .venv/bin/activate
pip install strands-agents strands-agents-tools supabase fastapi uvicorn
```

Default model provider is **Amazon Bedrock** (or Google/Anthropic/OpenAI providers). Docs: [strandsagents.com](https://strandsagents.com).

### Sketch (official API only)

```python
# backend/study_life_agent.py
from strands import Agent, tool
from supabase import create_client, Client

sb: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE)  # server-only

@tool
def get_all_data(user_id: str) -> dict:
    """Subjects, topics, pending revisions, today's classes, daily items."""
    ...

@tool
def add_topic(user_id: str, subject_name: str, topic_name: str) -> str:
    """Create topic only. NO revision schedules until first-read is marked done."""
    ...

@tool
def mark_first_read_completed(user_id: str, subject_name: str, topic_name: str) -> str:
    """Set first_read_completed and insert 6 revision_schedules (day 1,3,7,14,30,90) from today."""
    ...

@tool
def complete_revision(user_id: str, schedule_id: str, topic_id: str) -> str:
    """Same as Flutter completeRevision: status=completed + topic.total_revisions++."""
    ...

@tool
def register_daily_routine(user_id: str, date_iso: str, items: list) -> str:
    """Validate every study subject exists; insert daily_routines row."""
    ...

@tool
def register_class_routine(user_id: str, subject_name: str, start_time: str,
                           duration_minutes: int, dates: list = None,
                           recurring_days: list = None, location: str = None) -> str:
    ...

@tool
def recover_missed_revisions(user_id: str) -> dict:
    """List overdue schedules and propose reschedule plan (no write until confirm)."""
    ...

@tool
def build_exam_plan(user_id: str, exam_date: str, hours_per_day: int) -> dict:
    """Multi-day plan using real subjects/topics only; returns proposed routine blocks."""
    ...

@tool
def analyze_study_progress(user_id: str, days: int = 7) -> dict:
    """Completion % = completed / (topics × 6); sessions this week; weakest subjects."""
    ...

study_life_agent = Agent(
    system_prompt=(
        "You are Putu's study agent for Smart Revision Tracker. "
        "Never invent subject or topic names. "
        "Revision days: 1,3,7,14,30,90 only after first_read_completed. "
        "Ask before bulk deletes or replacing an entire day's routine."
    ),
    tools=[
        get_all_data, add_topic, mark_first_read_completed, complete_revision,
        register_daily_routine, register_class_routine,
        recover_missed_revisions, build_exam_plan, analyze_study_progress,
    ],
)
```

### HTTP wrapper (FastAPI + Lambda or App Runner)

```python
# backend/main.py
@app.post("/v1/agent/invoke")
async def invoke(payload: dict, authorization: str = Header(...)):
    user_id = verify_supabase_jwt(authorization)  # never trust client user_id alone
    result = study_life_agent(payload["task"])  # or invoke_async
    return {"summary": str(result), "needsConfirmation": ...}
```

Deploy: **AWS Lambda** for demo, or **AgentCore** if you want managed hosting later ([docs](https://strandsagents.com/docs/user-guide/deploy/deploy_to_bedrock_agentcore/)).

---

## 4. What stays on Gemini Live vs moves to Strands

| Gemini Live only | Strands (Python) |
|------------------|------------------|
| Mic, STT, TTS, turn-taking | Every former Gemini function: `addTopic`, `markFirstReadCompleted`, `registerDailyRoutine`, … |
| Short spoken confirmation of agent result | Multi-step: exam plan, missed recovery, conflict resolution, weekly analysis |
| | Background “daily monitor” job (same agent + tools) |

**Flutter change:** one Gemini tool, e.g. `strands_run_task(task: string)`, **or** no Live tools at all — send transcript to backend and TTS the reply.

---

## 5. Confirmation rules

| Action | Confirm in Flutter? |
|--------|---------------------|
| Read-only (`get_all_data`, analyze) | No |
| Single `complete_revision` / `add_topic` | No (same as Today swipe) |
| Replace full `daily_routines` day | **Yes** |
| Bulk reschedule overdue | **Yes** |
| Delete subject / daily routine | **Yes** |

Return `{ needsConfirmation: true, question, action }`; Flutter sheet on Approve → second `/v1/agent/invoke` or a dedicated `/v1/actions/apply`.

---

## 6. Background monitoring

Cron (EventBridge + Lambda) or app WorkManager → `POST /v1/agent/invoke` with task `daily_monitor`.

Checks: overdue > N days · class in 60 min without daily block · first-read stalled · tomorrow’s class without plan.

**Notify only when a decision is required** (one full-screen reminder max per category/day) via existing `NotificationService` after the agent writes a small `agent_alerts` row or triggers a push through your backend.

---

## 7. Security

- **Service role key only on the Python server.** Flutter keeps anon + RLS.  
- Auth: Flutter sends Supabase **JWT**; backend verifies and uses `user_id` from token.  
- No Bedrock/Gemini secrets in the APK beyond what you already expose for Live.  
- Assistant name remains **Putu**; never leak model names (same as current Gemini prompt).

---

## 8. Errors & testing

| Failure | Behavior |
|---------|----------|
| Strands timeout | HTTP 504 → Gemini: “planning slow, try again” — no partial write |
| Tool error | `{success:false}` → spoken error |
| JWT invalid | 401, no agent run |

**Tests:** tool unit tests on Supabase seed data · contract test Flutter ↔ `/v1/agent/invoke` · E2E voice: “exam plan in 30 days” → confirm → `daily_routines` · regression: topic add + first-read + complete still work.

---

## 9. Migration (minimal Flutter rewrite)

1. Stand up Python Strands backend + JWT verify + one tool (`get_all_data`).  
2. Add `lib/app/data/services/strands_service.dart` (`invokeAgent(task)`).  
3. Wire voice: after Gemini transcript → `invokeAgent` → `GeminiLiveService` TTS of `summary`.  
4. Start Gemini Live **without** `tools` (or keep only `strands_run_task` temporarily).  
5. Port remaining `_handleFunctionCall` handlers into Python `@tool` functions one-for-one (same table names/columns).  
6. Delete Gemini tool list when Strands path is proven.

Existing UI/realtime/notifications stay as they are.

---

## 10. Hackathon fit

- **Real `strands-agents` package** (pip) — clear “built with Strands” story  
- Gemini Live only as the voice front-end  
- Supabase remains the single DB the Flutter app already streams  
- Demo: voice → Strands tools → Today/Calendar/widgets update → TTS reply  

**MVP (1–2 days):** FastAPI + `get_all_data` + `register_daily_routine` + `complete_revision` + Flutter `strands_service` + TTS bridge → then exam-plan / missed-recovery tools.

---

## 11. Non-goals

- Do **not** port Strands into Dart or invent a pub package.  
- Do **not** keep Gemini Live function-calling after migration.  
- Do **not** duplicate `revisionDays` / `completeRevision` logic in two write paths.  
- Do **not** use only APIs from official docs: `from strands import Agent, tool`, `Agent(tools=[...])`, model providers as documented.
