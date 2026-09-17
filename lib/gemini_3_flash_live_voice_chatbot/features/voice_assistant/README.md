# Voice Assistant (Gemini Live)

Floating AI study coach: voice + text chat that can read/write your subjects,
topics, revisions, and routines via Supabase.

---

## Start here (mental model)

```
User taps mic / types
        │
        ▼
VoiceAssistantController          ← UI state + orchestration
        │
        ▼
GeminiLiveService                 ← session start/stop, mute, send
        │
        ▼
GeminiSocket                      ← WebSocket to Gemini Live API
        │
        ▼
function-call tools               ← controller/tools_*.dart
        │
        ▼
Supabase (app/data/*)             ← real data
```

---

## Folder map

| Path | What it is |
|------|------------|
| `voice_assistant_controller.dart` | **Shell only** — fields, lifecycle hooks, `sendText`. All logic is in `controller/`. |
| `voice_assistant_screen.dart` | Full-screen chat page (pushed from Subjects / Routine). |
| `study_assistant_dialogue.dart` | Floating card overlay (used from most tabs). |
| `voice_assistant_binding.dart` | GetX binding (registers the controller). |
| `controller/` | All controller behavior, split by responsibility (see below). |
| `widgets/full_screen/` | Private widgets for **`VoiceAssistantScreen`**. |
| `widgets/floating_dialogue/` | Private widgets for **`StudyAssistantDialogue`**. |
| `widgets/shared/` | Mic button + wave animation used by both UIs. |

---

## `controller/` — who does what

| File | Responsibility |
|------|----------------|
| `session_lifecycle.dart` | Connect, reconnect, stop; wire Gemini streams to UI state. |
| `mic_state.dart` | Mute/unmute, echo-guard, mic reconcile timer. |
| `function_call_batching.dart` | Collects Gemini tool results and sends them in one batch. |
| `tools_definition.dart` | **Schema** of tools the model is allowed to call. |
| `tools_subject_read.dart` | `getAllData`, `getSubjectDetail` (read-only). |
| `tools_subject_create_delete.dart` | `addSubject`, `addTopic`, `delete*` (writes). |
| `tools_topic_revision.dart` | `markFirstReadCompleted`, `markRevisionCompleted`, topic status. |
| `tools_class_daily_routine.dart` | `registerClassRoutine`, `registerDailyRoutine`. |
| `dialogue_panel_sizing.dart` | Floating panel size, drag position, resize clamps. |

> These are `part of` the controller library — they can use private fields
> (`_service`, `_pendingCallIds`, …) without exposing them publicly.

---

## Tool modes (what the AI is allowed to do)

Set by other screens on the controller:

- `toolMode = 'full'` — default (Subjects / Topic detail)
- `toolMode = 'routine'` — Routine tab: can **read** data and **create**
  class/daily routines; **cannot** delete subjects/topics
- `currentRoutineMode = 'daily' | 'class'` — which routine kind the tool should write

Blocked tool sets live in `voice_assistant_controller.dart`
(`_routineBlockedTools`, `_subjectBlockedTools`).

---

## Related packages (outside this feature folder)

| Path | Role |
|------|------|
| `../../services/gemini_live_service.dart` | Low-level Live session + audio mute |
| `../../core/websocket/` | Socket connect / parse / send |
| `../../core/audio/` | Recorder + player (io vs web) |
| `../../config/gemini_config.dart` | Model name, API key env, voice |

---

## Adding a new voice tool

1. Declare it in `controller/tools_definition.dart` (name, description, params).
2. Implement the handler in the matching `tools_*.dart` file.
3. Wire the name in the function-call switch inside
   `controller/function_call_batching.dart` (or session lifecycle if that’s
   where dispatch lives — search for existing tool names like `getAllData`).
4. If it is a write, invalidate `_summaryCache` (see comment on the field).
