# Smart Revision Tracker

**A complete study companion: spaced revision · class & daily routines · home-screen widgets · voice AI (Pootu).**

One Flutter app so students remember what they learned — not just the night before the exam.

| | |
|---|---|
| **Platforms** | Android · iOS · Web (Chrome/Safari/Firefox) · Desktop-ready |
| **Backend** | Supabase (Postgres + Auth + Realtime) |
| **Voice AI** | **Pootu** on Gemini Live (WebSocket STT + TTS) |
| **Agentic tools** | Optional AWS Bedrock **Strands Agents** (Python) |
| **Widgets** | 3 Android home-screen widgets (scrollable) |
| **Reminders** | Local notifications for revisions, classes, daily blocks |

---

## 1. Vision, mission & the problem we solve

A student’s study process is often **unorganized and fragmented** — and that is the real problem, not “forgetting” alone.

They open a chapter, study it once, and lose most of it within hours or days because nothing forces a structured review. There is rarely a clear record of **when** they studied, **which subject** it was, and **which topic** they actually covered. Planning lives in paper, pen, notebooks, phone notes, calendars, and a pile of different apps. Class timetables sit apart from personal study plans, which sit apart from revision lists. When exam week arrives, the same questions return: *What have I already finished? What is still left? What should I study right now? How am I actually doing across subjects?* There is almost no reliable view of completed vs remaining topics, and no subject- or topic-level sense of progress. So students spend mental energy **organizing instead of studying** — the worst trade when the syllabus is large and the timeline is long.

That cost becomes even sharper during **competitive-exam preparation**. BCS, NEET, JEE, UPSC, USMLE, MCAT, SAT, GRE, GMAT, Gaokao, and similar high-stakes exams demand months of coverage across many subjects, with material that must be **revisited repeatedly**, not just read once. Without one system that remembers what was learned and when it should come back again, even hard-working students fall behind.

**Smart Revision Tracker** is that missing system — one organized study workspace, not another reminder app, calendar, flashcard deck, timetable, or chatbot.

It records **subjects and topics**, tracks **first-read completion**, and only then automatically schedules spaced revisions on **Day 1 · 3 · 7 · 14 · 30 · 90**. It surfaces **today’s, missed, and upcoming** work so nothing silently disappears. It keeps **class routines** and **daily study routines** in the same place as revision planning. It tracks what is completed versus what remains, with history, progress, streaks, and completion stats. Reminders cover revisions, classes, and the **current daily study block**. On Android, **home-screen widgets** show what to do next without reopening the app. And **Pootu**, the voice study assistant, cuts the friction of entering and managing all of that while you are already at the desk.

The product exists to answer one practical question every day:

> **“What should I study or revise now?”**

The outcome we want is simple and human: students should know **what they studied, what they remember, what needs revision, what is still left, how they are progressing, and what to do next** — without organizing everything by hand. Less planning friction. More consistent learning. Memory that lasts past the night before the exam.

Built for school and university students in general (Bangla / English / Banglish), and especially powerful for anyone grinding a large competitive syllabus where structured revision is not optional.

---

## 2. Pootu — voice study AI (major feature)

Pootu is the headline feature: **hands-free control of your real study data**. Tools write the same Supabase tables the UI uses — no fake replies.

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
- Identity: **Pootu** — never reveals model/vendor names  
- Replies match the user’s language (EN / BN / Banglish)

**Web/desktop audio:** Web Audio capture (resampled to 24 kHz PCM) + smooth scheduled playback (edge fades, seam overlap).

**In-app UI:** Floating assistant panel, draggable, **resizable from all four corners** on desktop/tablet.

---

## 3. Features overview

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

## 4. Web & desktop shell

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
- **Settings │ About this app** (soft animated guide: vision, problem, Pootu capabilities, manual)

**Other desktop polish**
- Auth: **image left, form right**  
- Topic list max-width ~680 so actions stay readable  
- Settings profile **refreshes on every auth event** and when the tab opens  
- Widget promo dialog: **phone only**  
- Slow ease-in workspace transition on sidebar tab change  

---

## 5. Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  Flutter (Android · iOS · Web · Desktop)                    │
│  GetX UI │ WidgetDataProvider │ Gemini Live client (Pootu)   │
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

## 6. Agentic workflow

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

## 7. Repository layout

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

## 8. Data model (Supabase)

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

## 9. Spaced-revision product logic

```text
Add topic
   → [First Read] ──complete──► schedules: +1, +3, +7, +14, +30, +90
   → each due day: Today tab / widget / notification
   → complete → total_revisions++ · miss → Missed / recovery
```

Invariant: days are only `[1, 3, 7, 14, 30, 90]` everywhere.

---

## 10. Getting started

```bash
flutter pub get

# Debug
flutter run -d chrome
flutter run -d android

# Web release (const SubjectIcons map enables icon tree-shake)
flutter build web --release
```

Optional Strands backend: see `AWS_STRANDS_AGENT_INTEGRATION/README.md`.

### Password reset (built-in Supabase Auth)

The app uses Supabase’s normal recovery APIs — no custom backend:

1. `auth.resetPasswordForEmail(...)` — sends the official recovery email  
2. `AuthChangeEvent.passwordRecovery` — fires when the user taps the link  
3. `auth.updateUser(password)` — saves the new password  

**You do not need a production website.** For Android/iOS the email links back into the app via the custom scheme already in the manifests:

```
study-revision-tracker://recovery
```

**One-time dashboard step** — Supabase → **Authentication → URL Configuration → Redirect URLs**:

```
study-revision-tracker://recovery
```

(Site URL can stay on the default. Optional for local web only: `http://localhost:PORT/auth?recovery=1`.)

Flow: Sign In → Forgot password? → open email link → app opens → set new password → Home.

---

## 11. Demo script (judges, 3–5 min)

1. **Auth** desktop: art left, form right.  
2. **Dashboard** — due counts, Start Revising.  
3. **Subjects** — add subject; open in side pane; add topic.  
4. **Complete first read** → Day 1…90 appear.  
5. **Today** — Today / Missed / Upcoming; swipe complete.  
6. **Routine** — Daily | Class side-by-side.  
7. **Pootu** — “Add topic …”, “Plan my day”, “What’s due this week?”  
8. **Settings | About** — vision, Pootu capability list, manual.  
9. **Android widgets** — Revision 3-tab, Class ListView, Daily countdown.  
10. **Resize browser** — sidebar collapse, split panes, 4-corner assistant resize.

---

## 12. Impact & differentiation

| Pain | How this solves it |
|------|---------------------|
| Forgetting after one read | Automatic 6-step spaced schedule |
| Scattered plans | Subjects + class + daily + calendar in one graph |
| Phone friction while studying | **Pootu voice** writes real rows |
| App-open cost | Widgets + auto reminders |
| Desktop study sessions | Split workspace, not a stretched phone UI |

**Not another flashcard clone** — a **study operating system** with a voice agent and a strict scientific schedule engine.

---

## 13. Tech stack

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

## 14. Docs map

| File | Contents |
|------|----------|
| `README.md` | Product, vision, Pootu, architecture, demo |
| `STRANDS_AGENT_INTEGRATION.md` | Gemini voice vs Strands tools |
| `AWS_STRANDS_AGENT_INTEGRATION/README.md` | Docker / AgentCore deploy |

---

**Pootu says:** revise on Day 1, not the night before. 📚
