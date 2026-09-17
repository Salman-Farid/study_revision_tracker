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
| `tool_dispatch.dart` | **Name → handler switch** — add new tools here. |
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

## Adding a new voice tool (exactly 3 files)

| Step | File | What to do |
|------|------|------------|
| 1 | `controller/tools_definition.dart` | Add `{name, description, parameters}` so Gemini can call it |
| 2 | `controller/tools_*.dart` | Implement `Future<void> _myTool(String callId, Map args)` and call `_respondToFunction(...)` |
| 3 | `controller/tool_dispatch.dart` | Add `case 'myTool': await _myTool(callId, args);` |

Then:
- Write? Set `_summaryCache = null` so the next `getAllData` refetches.
- Screen lock? Add the name to `_routineBlockedTools` / `_subjectBlockedTools` in `voice_assistant_controller.dart`.

## Mic open/close timing

**All timing knobs are in one file:** `controller/mic_state.dart` (top of file).

| Constant | Meaning | Default |
|----------|---------|---------|
| `_kUnmuteDebounce` | How long after Gemini “turn complete” before the mic reopens | 500 ms |
| `_kEchoGuardWindow` | Ignore user speech that echoes the last assistant reply | 2 s |
| `_kMicReconcilePeriod` | How often UI mute state is re-synced with the audio service | 2 s |

Related methods (same file):
- `_setMicMuted` — single write path to the audio service
- `toggleListening` — user mic button
- `scheduleUnmuteAfterTurn` — called from `session_lifecycle.dart` after each turn
- `_enterLoading` / `_unmuteAfterFunctionCall` — mute while a tool runs

If the mic opens too early after Gemini speaks, raise `_kUnmuteDebounce`.
If it stays muted too long, lower it or check `_pendingCallIds` / batch flags.

