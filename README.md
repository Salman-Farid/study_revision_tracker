# Smart Revision Tracker

**A complete study companion: spaced revision · class & daily routines · home-screen widgets · voice AI (Putu).**

One Flutter app so students remember what they learned — not just the night before the exam.

| | |
|---|---|
| **Platforms** | Android · iOS · Web (Chrome/Safari/Firefox) · Desktop-ready |
| **Backend** | Supabase (Postgres + Auth + Realtime) |
| **Voice AI** | **Putu** on Gemini Live (WebSocket STT + TTS) |
| **Agentic tools** | Optional AWS Bedrock **Strands Agents** (Python) |
| **Widgets** | 3 Android home-screen widgets (scrollable) |
| **Reminders** | Local notifications for revisions, classes, daily blocks |

---

## 1. Vision & mission

### Vision
Every student remembers what they learned — months later — with almost zero planning overhead.

### Mission
Unify **spaced revision**, **class timetable**, **daily study blocks**, **home-screen widgets**, and a **voice-first AI assistant** into one calm workspace — so “what should I study now?” is always answered.

---

## 2. The problem we solve

- Study a chapter once → forget it in days.  
- Class schedule, daily plan, and revision list live in different notebooks/apps.  
- Cramming feels productive but destroys long-term memory.  
- Typing subjects, topics, and routines on a phone while studying is slow.  
- Opening an app just to check “what’s next?” breaks focus.

### The complete system

1. Finish **First Read** on a topic → auto-schedule revisions **Day 1 · 3 · 7 · 14 · 30 · 90**.  
2. Track **Today / Missed / Coming Up**; swipe-complete on mobile.  
3. Build **Class routines** and **Daily routines** (side-by-side on desktop).  
4. On Android: pin **widgets** + **auto reminders** for the current daily block.  
5. Talk to **Putu** — add, complete, plan, and delete with your voice.

**Who it’s for:** University & school students (Bangla / English / Banglish) who want less friction than a spreadsheet.

---

## 3. Putu — voice study AI (major feature)

Putu is the headline feature: **hands-free control of your real study data**. Tools write the same Supabase tables the UI uses — no fake replies.

| Capability | What you can say / do |
|------------|------------------------|
| **Add subjects & topics** | “Add Biology” · “Add topic Photosynthesis under Biology” |
| **Mark completed** | “Mark first read done for Algorithm” · “Complete Day 3 revision of Geometry” |
| **What’s due when** | “Which topics need revision this week?” — real schedules, real dates |
| **Study performance** | Ask for progress, overdue load, or overall situation from live data |
| **Full daily routine** | “Plan my day” — existing subjects/topics + **today’s classes** + **today’s revisions** auto-included |
| **Class routines** | “Physics at 10 for 90 minutes in Room 204 on Mon/Wed” |
| **Delete safely** | Remove subject, topic, or routine by voice (confirm before destructive actions) |
| **Voice-first loop** | Gemini Live streams mic audio; TTS answers; UI updates via Realtime |

**Rules baked into the agent**
- Never invent subject/topic names  
- Revisions only on **1, 3, 7, 14, 30, 90**  
- Schedules only after **first read complete**  
- Identity: **Putu** — never reveals model/vendor names  
- Replies match the user’s language (EN / BN / Banglish)

**Web/desktop audio:** Web Audio capture (resampled to 24 kHz PCM) + smooth scheduled playback (edge fades, seam overlap).

**In-app UI:** Floating assistant panel, draggable, **resizable from all four corners** on desktop/tablet.

---

## 4. Features overview

### Study core
| Feature | Detail |
|--------|--------|
| Subjects & topics | Color, icon, optional Unsplash cover, progress per subject |
| First read → revisions | Schedule **only when first read is completed** |
| Spaced days | **1, 3, 7, 14, 30, 90** — shared by Flutter + agent tools |
| Complete revision | Single write path → schedule + `total_revisions` + streams |
| Today tab | **Today · Missed · Upcoming**; swipe left to complete |
| Calendar | Month view of pending/overdue revisions |
| History / stats | Streak, completion rate, weekly activity |
| Topic cards | Compact desktop layout: reorder grip, Complete, delete |

### Routines
| Feature | Detail |
|--------|--------|
| Class routine | Subject, time, duration, location, recurring days |
| Daily routine | Study, first-read, revision, break, meal, nap, recall… |
| Desktop | **Daily \| Class side-by-side** — no toggle |
| Mobile | Toggle Daily / Class (original phone UX) |

### Home-screen widgets (Android)
| Widget | Behavior |
|--------|----------|
| **Revision** | **Today / Missed / Coming Up** toggle row; scrollable ListView |
| **Class routine** | Today only; scrollable ListView; NOW header; duration pill when wide |
| **Daily routine** | Chronometer + current/next block |

### Auto reminders
- Revision notifications (timezone-aware, Asia/Dhaka-ready)  
- Class reminders (e.g. 30 minutes before)  
- **Daily routine** alarms for the **current time block**  
- WorkManager + AlarmManager refresh so widgets stay fresh with the app closed  

---

## 5. Web & desktop shell

| Breakpoint | Experience |
|------------|------------|
| Phone (&lt; 760) | Bottom nav + IndexedStack — **mobile layout preserved** |
| ≥ 760 | **Card sidebar** (expand 248px / collapse 76px) |
| ≥ 980 | **2-pane split** |
| ≥ 1480 | Extra panes where useful |

**Split pairings**
- Dashboard │ History  
- Subjects │ Subject detail (select on the grid)  
- Today │ Calendar  
- Routine │ full-width **Daily + Class**  
- **Settings │ About this app** (soft animated guide: vision, problem, Putu capabilities, manual)

**Other desktop polish**
- Auth: **image left, form right**  
- Topic list max-width ~680 so actions stay readable  
- Settings profile **refreshes on every auth event** and when the tab opens  
- Widget promo dialog: **phone only**  
- Slow ease-in workspace transition on sidebar tab change  

---

## 6. Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  Flutter (Android · iOS · Web · Desktop)                    │
│  GetX UI │ WidgetDataProvider │ Gemini Live client (Putu)   │
└──────┬────────────┬────────────────────┬────────────────────┘
       │            │                    │ WSS
       ▼            ▼                    ▼
┌────────────┐ ┌────────────┐   ┌────────────────────┐
│ Supabase   │ │ Native     │   │ Gemini Live API    │
│ Auth+DB    │ │ widgets +  │   │ STT + TTS          │
│ Realtime   │ │ notifs     │   └─────────┬──────────┘
└─────┬──────┘ └────────────┘             │ tool JSON
      │                                   ▼
      │                      ┌────────────────────────┐
      └──────────────────────│ Optional Strands Agent │
             same tables     │ Bedrock / Python tools │
                             └────────────────────────┘
```

**Rules:** one data source (Postgres) · Gemini = voice only · widgets render prefs Flutter writes · mobile UX stays sacred.

---

## 7. Agentic workflow

### A. In-app voice (production)
```text
Speak → Gemini Live STT → tool call JSON
  → Flutter executes against Supabase
  → result → model → TTS speech
  → UI refreshes via Realtime streams
```

### B. Optional server agent
[`AWS_STRANDS_AGENT_INTEGRATION/`](./AWS_STRANDS_AGENT_INTEGRATION/) — official **Python `strands-agents`** on Bedrock AgentCore (linux/arm64, port 8080, `GET /ping`, `POST /invocations`).

```text
Gemini STT → Flutter → POST /v1/agent/invoke { task, mode, jwt }
  → StudyLifeAgent tools → Supabase (service role)
  → JSON → Flutter → Gemini TTS
```

---

## 8. Repository layout

```text
study_revision_tracker/
├── README.md
├── STRANDS_AGENT_INTEGRATION.md
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── core/          # constants, responsive, localization, services
│   │   ├── data/          # models, repositories, supabase_service
│   │   ├── modules/       # auth, dashboard, subjects, today, routine, …
│   │   │   └── navigation/# MainNavigation + AppSidebar
│   │   ├── modules/settings/  # Settings + About this app panel
│   │   └── routes/ theme/ widgets/
│   └── gemini_3_flash_live_voice_chatbot/
│       ├── features/voice_assistant/
│       ├── services/gemini_live_service.dart
│       └── core/audio/    # IO + Web mic/player
├── android/               # Kotlin widgets (Revision / Class / Daily)
├── ios/ HomeWidgetExtension
├── web/ assets/ supabase/
└── AWS_STRANDS_AGENT_INTEGRATION/   # optional Python agent
```

---

## 9. Data model (Supabase)

| Table | Purpose |
|-------|---------|
| `subjects` | name, color, icon, image, archived |
| `topics` | subject_id, name, first_read_completed, total_revisions |
| `revision_schedules` | topic_id, scheduled_date, day_number, status |
| `revision_sessions` | recall rating, confidence |
| `class_routines` | subject, time, duration, location, recurring days |
| `daily_routines` | date + JSON items |

RLS: rows scoped to `user_id`. Widgets read **SharedPreferences** written by Flutter.

---

## 10. Spaced-revision product logic

```text
Add topic
   → [First Read] ──complete──► schedules: +1, +3, +7, +14, +30, +90
   → each due day: Today tab / widget / notification
   → complete → total_revisions++ · miss → Missed / recovery
```

Invariant: days are only `[1, 3, 7, 14, 30, 90]` everywhere.

---

## 11. Getting started

```bash
flutter pub get

# Debug
flutter run -d chrome
flutter run -d android

# Web release (dynamic IconData → disable icon tree-shake)
flutter build web --release --no-tree-shake-icons
```

Optional Strands backend: see `AWS_STRANDS_AGENT_INTEGRATION/README.md`.

---

## 12. Demo script (judges, 3–5 min)

1. **Auth** desktop: art left, form right.  
2. **Dashboard** — due counts, Start Revising.  
3. **Subjects** — add subject; open in side pane; add topic.  
4. **Complete first read** → Day 1…90 appear.  
5. **Today** — Today / Missed / Upcoming; swipe complete.  
6. **Routine** — Daily | Class side-by-side.  
7. **Putu** — “Add topic …”, “Plan my day”, “What’s due this week?”  
8. **Settings | About** — vision, Putu capability list, manual.  
9. **Android widgets** — Revision 3-tab, Class ListView, Daily countdown.  
10. **Resize browser** — sidebar collapse, split panes, 4-corner assistant resize.

---

## 13. Impact & differentiation

| Pain | How this solves it |
|------|---------------------|
| Forgetting after one read | Automatic 6-step spaced schedule |
| Scattered plans | Subjects + class + daily + calendar in one graph |
| Phone friction while studying | **Putu voice** writes real rows |
| App-open cost | Widgets + auto reminders |
| Desktop study sessions | Split workspace, not a stretched phone UI |

**Not another flashcard clone** — a **study operating system** with a voice agent and a strict scientific schedule engine.

---

## 14. Tech stack

| Layer | Choice |
|-------|--------|
| App | Flutter + GetX |
| DB / Auth / Realtime | Supabase |
| Voice | Gemini Live WebSocket |
| Charts | fl_chart |
| Android widgets | RemoteViews + RemoteViewsService (ListView) |
| Notifications | flutter_local_notifications + timezone |
| Background | WorkManager (mobile) |
| Optional agent | Strands Agents (Python) on AgentCore |
| Web audio | `package:web` AudioContext |

---

## 15. Docs map

| File | Contents |
|------|----------|
| `README.md` | Product, vision, Putu, architecture, demo |
| `STRANDS_AGENT_INTEGRATION.md` | Gemini voice vs Strands tools |
| `AWS_STRANDS_AGENT_INTEGRATION/README.md` | Docker / AgentCore deploy |

---

**Putu says:** revise on Day 1, not the night before. 📚
