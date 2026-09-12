# Smart Revision Tracker

**Spaced-repetition study OS for students — with voice AI, home-screen widgets, and a cross-platform Flutter shell.**

One app to track subjects & topics, schedule **1 / 3 / 7 / 14 / 30 / 90-day** revisions after first read, plan daily & class routines, and talk to **Putu** — a voice study assistant that writes to the same database the UI uses.

| | |
|---|---|
| **Platforms** | Android · iOS · Web (Chrome/Safari/Firefox) · Desktop-ready Flutter |
| **Backend** | Supabase (Postgres + Auth + Realtime) |
| **Voice** | Gemini Live (WebSocket) — STT + TTS only |
| **Agentic tools** | Optional AWS Bedrock **Strands Agents** Python service |
| **Widgets** | 3 Android home-screen widgets (scrollable) |

---

## 1. Problem & Motivation

### The real-life problem
Students don’t fail exams because they never studied once — they fail because they **don’t revise at the right time**.

- Notes pile up; “I’ll revise later” never happens.
- Cramming the night before looks productive but has terrible long-term retention.
- Class schedules, daily plans, and revision lists live in **different notebooks / apps**.
- Typing subjects, topics, and routines on a phone is slow; **voice is natural while studying**.

### Why spaced repetition (and why this product)
Cognitive science (Ebbinghaus forgetting curve; active recall) shows memory survives when review is spaced: **Day 1 → 3 → 7 → 14 → 30 → 90**. Most spaced-rep apps are flashcard-only. This product is a **full study operations layer**:

1. **Subjects & topics** with first-read completion  
2. **Automatic revision schedule** only after first read (not on mere add)  
3. **Today / Missed / Coming Up** workflow with swipe-to-complete  
4. **Class routine + daily routine** in one place  
5. **Home-screen widgets** so the plan is visible without opening the app  
6. **Voice assistant (Putu)** that can add topics, mark revisions, and build routines via tools  

### Who it’s for
University & school students (especially in South Asia — Bangla/English/Banglish support) who already use their phone as a second brain and want less friction than a spreadsheet.

---

## 2. Features (judge cheat-sheet)

### Study core
| Feature | Detail |
|--------|--------|
| Subjects & topics | Color, icon, optional cover image (Unsplash), progress per subject |
| First read → revisions | Schedule **created only when first read is completed** |
| Spaced days | Hard-coded **1, 3, 7, 14, 30, 90** — same list in Flutter + agent tools |
| Complete revision | Single write path: schedule + `total_revisions` + streams (UI stays in sync) |
| Today tab | Chips: **Today · Missed · Upcoming**; swipe left to complete |
| Calendar | Month view of pending/overdue revisions |
| History / stats | Streak, completion rate, weekly activity (real DB data) |
| Recovery | Missed revisions can be recovered / re-planned |

### Routines
| Feature | Detail |
|--------|--------|
| Class routine | Subject, time, duration, location, recurring days |
| Daily routine | Study blocks, first-read, revision, break, meal, nap, etc. |
| Desktop split | **Daily \| Class side-by-side** — no toggle on wide screens |
| Mobile | Toggle Daily / Class (unchanged phone UX) |

### Voice — “Putu”
| Feature | Detail |
|--------|--------|
| Gemini Live | Real-time duplex WebSocket; mic streams PCM; TTS plays reply |
| Tools on the wire | `getAllData`, `addTopic`, `markFirstRead`, `completeRevision`, `registerClassRoutine`, `registerDailyRoutine`, … |
| Identity | Always **Putu**; never reveals model/vendor names |
| Language | Replies in the same language as the user (EN / BN / Banglish) |
| Modes | Subjects screen vs Routine screen filter which tools are allowed |
| Web/desktop audio | Web Audio API capture (24 kHz resample) + smooth scheduled playback |

### Home-screen widgets (Android)
| Widget | Behavior |
|--------|----------|
| **Revision** | 3-way toggle **Today / Missed / Coming Up** in a scrollable row; ListView items |
| **Class routine** | Today’s classes only; **scrollable ListView**; NOW header; duration pill when wide |
| **Daily routine** | Chronometer countdown + current/next block |

### Web & desktop shell
- **Phone:** bottom nav (6 tabs) — original layout preserved  
- **Desktop/tablet:** card **sidebar** (expand/collapse, 248 / 76 px)  
- **Split panes:** Dashboard│History · Subjects│Detail · Today│Calendar · Routine (dual)  
- **Calendar** is not a desktop rail tab — it lives in the Today pane  
- Auth: **image left, form right** on wide screens  
- Study assistant: compact floating panel, **resizable from all 4 corners**  
- Widget promo dialog: **phone only** (no home widgets in browser)

### Platform hygiene
- Supabase session restore (localStorage on web, secure storage on mobile)  
- Notifications & WorkManager **native-only** (no-ops on web)  
- `dart:io` removed from HTTP paths (`package:http`)  
- Path URL strategy on web  

---

## 3. Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  Flutter app (single codebase)                              │
│  Android · iOS · Web · Desktop                              │
│                                                             │
│  UI (GetX)  │  WidgetDataProvider  │  Gemini Live client    │
└──────┬──────┴──────────┬───────────┴───────────┬────────────┘
       │                 │                       │
       │ HTTPS + Realtime│ SharedPreferences      │ WSS
       │                 │ (HomeWidget)           │
       ▼                 ▼                       ▼
┌──────────────┐  ┌──────────────┐   ┌──────────────────────┐
│  Supabase    │  │ Native       │   │ Gemini Live API      │
│  Auth        │  │ Android      │   │ (voice STT/TTS only) │
│  Postgres    │  │ widgets +    │   └──────────┬───────────┘
│  RLS         │  │ notifications│              │ tool calls
└──────┬───────┘  └──────────────┘              │ (JSON)
       │                                        ▼
       │                         ┌──────────────────────────┐
       │                         │ Optional: Strands Agent  │
       └─────────────────────────│ AWS Bedrock Runtime      │
              same tables        │ Python tools → Supabase  │
                                 └──────────────────────────┘
```

**Design rules**
1. **One data source** — Postgres via Supabase. No second revision engine.  
2. **Gemini Live = voice only** — tools can run in the Flutter controller *or* in the Python Strands service.  
3. **Widgets never invent data** — Flutter writes prefs; Kotlin only renders.  
4. **Mobile UX stays sacred** — web/desktop is an additive shell.

---

## 4. Agentic workflow (what judges care about)

### A. In-app voice agent (production path)
```text
User speaks
  → Gemini Live STT
  → Model decides tool call (structured JSON)
  → Flutter VoiceAssistantController executes tool against Supabase
  → Result returned to model
  → Model speaks natural language via TTS
  → UI updates via Realtime streams
```

**Hard rules in the system prompt**
- Never invent subject/topic names (must come from `get_all_data` / `get_subject_detail`)  
- Revisions only on days 1,3,7,14,30,90  
- Schedules only via `mark_first_read_completed`  
- Identity: Putu; no model name leaks  

### B. Optional server agent (AWS Strands)
Folder: [`AWS_STRANDS_AGENT_INTEGRATION/`](./AWS_STRANDS_AGENT_INTEGRATION/)

Official **Python `strands-agents` SDK** (no Dart Strands package exists).

| Piece | Role |
|-------|------|
| `app/core/agent.py` | `StudyLifeAgent` + system prompt + tool list |
| `app/tools/*.py` | `@tool` wrappers: subjects, revisions, routines, planning |
| `app/main.py` | FastAPI: `GET /ping`, `POST /invocations`, CORS |
| `agentcore_entry.py` | `BedrockAgentCoreApp` for AgentCore Runtime |
| `Dockerfile` | **linux/arm64**, port **8080** |
| `scripts/deploy_agentcore.py` | ECR push + `create_agent_runtime` sketch |

Flow when enabled:
```text
Gemini STT → Flutter → POST /v1/agent/invoke  { task, mode, jwt }
  → Strands Agent → tools → Supabase (service role)
  → JSON summary → Flutter → Gemini TTS
```

**Security:** JWT required; service role stays server-side; Flutter keeps anon key + RLS.

---

## 5. Repository layout

```text
study_revision_tracker/
├── README.md                          ← you are here
├── STRANDS_AGENT_INTEGRATION.md       ← architecture doc (voice vs Strands)
├── pubspec.yaml
│
├── lib/
│   ├── main.dart                      # Boot, Supabase, web-safe native guards
│   ├── app/
│   │   ├── core/
│   │   │   ├── constants/             # app_constants, responsive, size_constants
│   │   │   ├── localization/          # 20+ languages
│   │   │   ├── services/              # notifications, widgets, connectivity
│   │   │   └── web/                   # URL strategy (web only)
│   │   ├── data/
│   │   │   ├── models/                # subject, topic, revision, routines
│   │   │   ├── repositories/
│   │   │   └── services/              # supabase_service, gemini, image search
│   │   ├── modules/
│   │   │   ├── auth/                  # email + Google; split layout
│   │   │   ├── dashboard/
│   │   │   ├── subjects/              # grid, progress, side-pane selection
│   │   │   ├── subject_detail/        # topic cards, first-read, reorder
│   │   │   ├── topic_detail/
│   │   │   ├── today/                 # Today / Missed / Upcoming
│   │   │   ├── routine/               # daily + class (dual on desktop)
│   │   │   ├── calendar/
│   │   │   ├── statistics/            # History screen
│   │   │   ├── settings/
│   │   │   ├── navigation/            # MainNavigation + AppSidebar
│   │   │   └── splash/
│   │   ├── routes/
│   │   ├── theme/
│   │   └── widgets/
│   └── gemini_3_flash_live_voice_chatbot/
│       ├── features/voice_assistant/  # UI + tool-calling controller
│       ├── services/gemini_live_service.dart
│       ├── core/audio/                # IO + Web mic/player (conditional)
│       ├── core/websocket/            # Live API socket
│       └── config/
│
├── android/                           # Kotlin widgets + receivers
│   └── app/src/main/
│       ├── kotlin/.../                # Revision/Class/Daily widget + factories
│       └── res/layout|xml/            # widget layouts & provider info
├── ios/                               # HomeWidgetExtension
├── web/                               # index.html boot splash, icons
├── assets/images/auth_study.png
├── supabase/migrations/
│
└── AWS_STRANDS_AGENT_INTEGRATION/     # isolated Python agent (optional)
    ├── app/  tools/  Dockerfile  scripts/
```

---

## 6. Data model (Supabase)

| Table | Purpose |
|-------|---------|
| `subjects` | name, color, icon, image, archived |
| `topics` | subject_id, name, notes, first_read_completed, total_revisions |
| `revision_schedules` | topic_id, scheduled_date, day_number (1/3/7/14/30/90), status |
| `revision_sessions` | recall rating, confidence |
| `class_routines` | subject, time, duration, location, recurring days |
| `daily_routines` | date + JSON items (study/break/meal/…) |

RLS: each row scoped to `user_id`. Widgets read **SharedPreferences** written by Flutter (not the DB) so they work with the app killed.

---

## 7. Spaced-revision product logic

```text
Add topic
   │
   ▼
[First Read]  ──complete──►  create 6 schedules: +1, +3, +7, +14, +30, +90 days
   │
   ▼
Each due day → Today tab / widget / notification
   │
   ├── complete → total_revisions++, next day unlocks
   └── miss     → Missed tab / recovery
```

**Invariant:** days are only `[1, 3, 7, 14, 30, 90]`. UI, notifications, widgets, and agent tools all share this list.

---

## 8. Cross-platform UI strategy

| Breakpoint | Shell |
|------------|--------|
| &lt; 760 px | Phone: bottom NavigationBar + IndexedStack |
| ≥ 760 | Card sidebar (Dashboard, Subjects, Today, Routine, Settings) |
| ≥ 980 | 2-pane split (see architecture above) |
| ≥ 1480 | 3-pane where useful (Dashboard/Subjects/Today pairings) |

Topic cards cap at **~680 px** so Complete / bin / reorder stay readable on wide panes.

---

## 9. Getting started

### Prerequisites
- Flutter 3.22+ (SDK `^3.8.1`)
- Supabase project (URL + anon key)
- Gemini API key for Live voice
- Android SDK for widgets / APK

### Configure
Keys can be injected at build time (recommended) or temporarily via defaults in `lib/app/core/constants/app_constants.dart`.

```bash
flutter pub get

# Debug
flutter run -d chrome
flutter run -d android

# Web release (dynamic IconData subjects → disable icon tree-shake)
flutter build web --release --no-tree-shake-icons
```

### Optional Strands agent
```bash
cd AWS_STRANDS_AGENT_INTEGRATION
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # Supabase service role + Bedrock model
uvicorn app.main:app --host 0.0.0.0 --port 8080
```
See that folder’s `README.md` for AgentCore deploy (arm64, `/ping`, `/invocations`).

---

## 10. Demo script (3–5 minutes for judges)

1. **Auth** — desktop: art left, form right; sign in.  
2. **Dashboard** — hero “N revisions due today”, stats, Start Revising.  
3. **Subjects** — add subject; tap → detail pane opens beside the grid.  
4. **Add topic → Complete first read** → schedule appears (Day 1…90).  
5. **Today** — Today / Missed / Upcoming; swipe complete.  
6. **Routine** — desktop shows Daily \| Class side-by-side.  
7. **Voice** — tap mic: “Add topic Photosynthesis under Biology”; confirm DB + UI.  
8. **Widgets** (Android device/emulator): Revision 3-toggle, Class ListView.  
9. **Web** — resize window: sidebar collapse, split panes, assistant 4-corner resize.

---

## 11. Impact & differentiation

| Pain | How this solves it |
|------|---------------------|
| Forgetting after one read | Automatic 6-step spaced schedule |
| Scattered plans | Subjects + routines + calendar in one graph |
| Phone friction while studying | Voice agent writes real rows |
| App-open cost | Home widgets + notifications |
| Desktop study sessions | Split workspace, not a stretched phone UI |

**Not another flashcard clone** — it’s a **study operating system** with an agentic voice front-end and a strict scientific schedule engine.

---

## 12. Tech stack

| Layer | Choice |
|-------|--------|
| App | Flutter + GetX |
| DB / Auth / Realtime | Supabase |
| Voice | Gemini Live WebSocket |
| Charts | fl_chart |
| Calendar UI | table_calendar |
| Android widgets | RemoteViews + RemoteViewsService (ListView) |
| Notifications | flutter_local_notifications + timezone (Asia/Dhaka-aware) |
| Background | WorkManager (mobile only) |
| Optional agent | Strands Agents (Python) on Bedrock AgentCore |
| Web audio | `package:web` AudioContext (mic + player) |

---

## 13. Docs map

| File | Contents |
|------|----------|
| `README.md` | Product + architecture + demo (this file) |
| `STRANDS_AGENT_INTEGRATION.md` | Why Gemini voice ≠ Strands tools; integration contract |
| `AWS_STRANDS_AGENT_INTEGRATION/README.md` | Deploy, Docker, AgentCore checklist |

---

## 14. License / credits

Built as a student productivity product. Voice stack: Google Gemini Live. Backend: Supabase. Agent SDK: AWS Strands Agents (optional path).

**Putu says:** revise on Day 1, not the night before. 📚
