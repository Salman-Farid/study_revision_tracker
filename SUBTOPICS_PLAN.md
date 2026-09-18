# Subtopics hierarchy — implementation plan

**Status:** Plan only (not implemented yet)  
**Scope:** Subject → Topic → Subtopic, progress, revisions, Today tab, voice tools  
**Constraint:** Reuse existing subject-details / topic-list UI + widgets wherever possible

---

## 1. Product rules (locked)

| Rule | Behavior |
|------|----------|
| Hierarchy | `Subject → Topic → Subtopic` (one level under topic — not infinite nesting) |
| Leaf topic | No children → **Complete** button + first-read / revision flow as today |
| Parent topic | Has ≥1 subtopic → **no Complete button**; **circular progress ring** + **% in the middle** |
| Subtopic “fully done” | Subtopic finished the **regular process**: first-read completed **AND** all **6 revisions** done (`first_read_completed && total_revisions >= 6`) |
| Parent → **Done** | **If and only if** every subtopic is fully done → parent card moves **directly under Done** |
| Parent → **Revision** | **Never.** Parent does **not** enter revision flow. Children already went through first-read + all revisions; parent is a **rollup only** |
| Parent not all done | Stay on subject list with **ring + %** (not Complete, not In Revision as its own study item) |
| Ring % | **Calculated** from subtopic progress (see §3 / §9) — not a simple “1 of N topics” count only |
| Subject % | Must **include subtopic** completion in the subject progress number |
| Tap topic | Opens **same subject-details style screen** listing that topic’s **subtopics** (same chips, search, cards) |
| Today / Missed / Upcoming | Show **Subject · Topic · Subtopic** when work is on a subtopic |
| Voice | After topic create (and on request), **ask** if user wants subtopics under that topic; tools to add/list/mark them |

---

## 2. Database (Supabase)

### Recommendation: one extra column on `topics` (maximum UI reuse)

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_add_subtopics.sql
alter table public.topics
  add column parent_topic_id uuid references public.topics(id) on delete cascade;

create index if not exists topics_parent_topic_id_idx
  on public.topics (parent_topic_id);

create index if not exists topics_user_subject_parent_idx
  on public.topics (user_id, subject_id, parent_topic_id);
```

- `parent_topic_id IS NULL` → top-level topic (current data unchanged)
- `parent_topic_id = <topic.id>` → subtopic
- **Revision schedules** keep using `topic_id` — for subtopics, `topic_id` = subtopic id
- Parent topic: **no** `revision_schedules` rows of its own (rollup status only)
- RLS: same as `topics` (user owns row)

**Why not a separate `subtopics` table?**  
Duplicates model/repo/revision/realtime/Today logic. Parent-id on `topics` lets `SubjectDetailScreen`, chips, search, first-read cards, and revision trail work with a simple “children of topic X” filter.

**Optional later:** `sort_order` int for drag order of subtopics (same as topics order key pattern).

---

## 3. Models

### `TopicModel` (extend)

```dart
final String? parentTopicId; // null = top-level topic
final int subtopicCount;     // number of children (0 = leaf)
final int subtopicsDone;     // children with first_read && revisions >= 6

bool get isSubtopic => parentTopicId != null;
bool get hasSubtopics => subtopicCount > 0;

/// Per-subtopic completion 0..1 (regular process: first-read + 6 revisions).
double subtopicCompletion(TopicModel child) {
  if (!child.firstReadCompleted) return 0;
  return (child.totalRevisions.clamp(0, 6)) / 6.0;
}

/// Parent ring percentage 0..1 — average of subtopic completion.
double get parentRingProgress {
  if (subtopicCount <= 0) return 0;
  // filled by controller with children list; see §9
  return subtopicsDone / subtopicCount; // fallback; prefer weighted §9
}

/// Parent is Done only when ALL subtopics completed full process.
bool get parentIsDone =>
    subtopicCount > 0 && subtopicsDone >= subtopicCount;
```

- Parse `parent_topic_id` from JSON
- `subtopicCount` / `subtopicsDone` + weighted % from controller aggregation (children loaded)

### Display helpers (Today / routine tiles)

```dart
String hierarchyLabel(String subject, String topic, String? subtopic) =>
  subtopic == null || subtopic.isEmpty
      ? '$subject · $topic'
      : '$subject · $topic · $subtopic';
```

Revision schedule / Today item gains optional `subtopicName` via join when `topic.parent_topic_id != null`.

---

---

## 4. Data layer

| Piece | Change |
|-------|--------|
| `topics_api.dart` | `fetchTopics(subjectId)` → also return all descendants or `fetchSubtopics(topicId)`; `createTopic(..., parentTopicId)`; mark-first-read / delete unchanged |
| `topic_repository.dart` | `getBySubject`, `getSubtopics(topicId)`, `create(..., parentTopicId)` |
| `supabase_service.dart` | Realtime already on `topics` — subtopics stream with parents automatically |
| `revision_repository` / schedules | No schema change if schedule rows use subtopic `topic_id` |
| `stats` / subject progress | Count leaf work + subtopic revisions toward subject % |

**Progress aggregation (client):**

```
subjectProgress =
  (sum of leaf topic revisions + sum of subtopic revisions)
  / ((leafTopics + subtopics) * 6)
```

Parent topic’s own `total_revisions` is **not** incremented by children; parent status is derived from children.

---

## 5. Controllers

### A. Reuse `SubjectDetailController` (preferred)

Add optional `parentTopicId` / `parentTopic`:

```dart
class SubjectDetailController {
  SubjectModel subject;
  TopicModel? parentTopic; // non-null = subtopic list mode
  String? get listScopeId => parentTopic?.id ?? subject.id;
}
```

- `load()` / realtime: topics where `subjectId == subject.id && parentTopicId == parentTopic?.id`
- Filters + **case-insensitive search** reuse as-is
- `showAddSheet()`: creates topic with `parentTopicId` when in subtopic mode
- Title: subject name **or** `TopicName — Subtopics`

### B. Thin wrapper `SubtopicController` (only if needed)

If routing wants a separate binding:

```dart
class SubtopicController extends SubjectDetailController {
  SubtopicController({required TopicModel parent, required SubjectModel subject})
      : super(initialSubject: subject, parentTopic: parent);
}
```

Same screen, same widgets — **no parallel UI code**.

---

## 6. UI (reuse first)

### Navigation

```
Subjects grid → SubjectDetail (topics of subject)
  Topic card tap → SubjectDetail in subtopic mode (subtopics of topic)
```

- Desktop pane: stack push or replace right pane with subtopic view + back
- Phone: `Get.toNamed` / push same `SubjectDetailScreen` with parent topic args
- Back from subtopics → previous subject topics list

### Topic cards (parent vs leaf)

| Card type | Complete | Right side |
|-----------|----------|------------|
| Leaf topic | **Complete** chip (today) | Delete |
| Parent topic | **No Complete** | **Circular progress ring** + **% in the center** + chevron |

**Parent ring UI**
- `Stack`: `CircularProgressIndicator(value: parentProgress01)` + centered text `XX%`
- Optional small line: `n/N subtopics done`
- **All subtopics fully done** → parent is **Done** (list filter `Done`) — ring 100% + Done badge; **never** shown as “In Revision”
- **Not all done** → parent stays in **All** / working list with ring %; **not** Complete; **not** its own revision item

**Filter chips for a parent row**
- `Done` ⇔ every subtopic `first_read_completed && total_revisions >= 6`
- Otherwise parent is **not** in Done and **not** in In Revision (no parent revision process)
- Parent appears under **All** always; under **First Read** only while no subtopic has started optional — **simplest:** parent uses **All + Done** only (ring communicates state)

Long names still wrap (existing fix).

### Subtopic list screen

- Same: filter chips (All / First Read / In Revision / Done), search, first-read cards, revision expandable cards
- Counts = that topic’s subtopics
- Add FAB = add **subtopic** under parent
- Optional small breadcrumb under AppBar: `CS / Artificial Intelligence`

### Subject cards (Subjects grid)

- Progress % uses formula in §4 (includes subtopics)
- Topic count label: e.g. `36 topics` or `12 topics · 40 subtopics` if we want clarity

---

## 7. Revisions & Today / Calendar / Routine

1. **Mark first read** on a **subtopic** → schedules `1,3,7,14,30,90` on that subtopic id (same as topics today).
2. Subtopic continues **regular revisions** until `total_revisions >= 6`.
3. When **every** subtopic is fully done → parent card **directly under Done** (no parent revision schedule, no “In Revision” for the parent).
4. **Today / Missed / Upcoming** tiles: resolve schedule → topic; if topic has `parent_topic_id`, show  
   `Subject · ParentTopic · Subtopic`  
   else `Subject · Topic` (current).
5. Routine / voice `getAllData`: expose subtopics under each subject/topic for “fast read” lists.

**Locked product choice:**  
- Work + schedules live on **leaf topics and subtopics** only.  
- Parent has **no** independent revision cycle.  
- Parent Done = **all** subtopics completed first-read **and** all 6 revisions.

---

## 8. Voice assistant (Study Assistant)

### Conversation flow

1. User: “add topic Artificial Intelligence under CS” → `addTopic` as today.  
2. Assistant **asks**: “AI topic added. Add subtopics under it? (e.g. Search, Neural Nets)” — **wait**.  
3. User lists names → `addSubtopics(subjectName, topicName, names[])` in one batch.  
4. User: “no” → stay leaf topic (Complete button path).

### New / extended tools

| Tool | Purpose |
|------|---------|
| `addSubtopics(subjectName, topicName, names[])` | Create children under topic |
| `getSubjectDetail` | Return topics **with** `subtopics[]` + parent ring % + parent done flag |
| `addTopic` | Optional `parentTopicName` / `subtopics[]` |
| Mark first read / revision | Same tools; allow **subtopic name** (resolve under topic) |
| `registerDailyRoutine` | Study blocks may name `subject / topic / subtopic` |

### Prompt rules

- After any **new topic** creation on routine/subjects screens → **ask once** about subtopics.  
- Never invent subtopic names.  
- Parent is **Done** only when all subtopics finished first-read + all revisions; **never** send parent into revision blocks.  
- `getAllData` / `getSubjectDetail` must list real subtopic names.  
- Language lock unchanged (one language per reply).

---

## 9. Completion logic (code) — LOCKED

```dart
// Leaf topic (no children) — unchanged
bool leafDone(TopicModel t) =>
    t.parentTopicId == null &&
    t.firstReadCompleted &&
    t.totalRevisions >= 6;

// Subtopic fully done = regular process complete
bool subtopicFullyDone(TopicModel s) =>
    s.firstReadCompleted && s.totalRevisions >= 6;

// Per-subtopic progress 0..1 for the parent ring
double subtopicCompletion(TopicModel s) {
  if (!s.firstReadCompleted) return 0;
  return s.totalRevisions.clamp(0, 6) / 6.0;
}

// Parent ring % (center text) — weighted by each subtopic’s revision progress
double parentRingPercent(List<TopicModel> children) {
  if (children.isEmpty) return 0;
  final sum = children.fold<double>(0, (a, c) => a + subtopicCompletion(c));
  return sum / children.length; // 0..1 → display as %
}

// Parent → Done filter ONLY
bool parentIsDone(List<TopicModel> children) =>
    children.isNotEmpty && children.every(subtopicFullyDone);

// Parent NEVER enters "In Revision" as a study/revision entity
// Parent NEVER has markFirstRead / revision schedules of its own
// When parentIsDone == true → show under Done; else ring with %
```

**Filter placement**
- `Done` chip count includes parents where `parentIsDone`
- `In Revision` / `First Read` counts use **leaf topics + subtopics only** (not parents)
- Parent rows live in **All** always; if `parentIsDone` also in **Done**; else visible in All with ring (not Complete)

When the last subtopic completes its last revision → topics realtime stream refreshes → parent card flips to Done + 100%.

---

## 10. Implementation order

| Step | Work | Notes |
|------|------|--------|
| 0 | Confirm plan | This doc |
| 1 | SQL migration + run on Supabase | `parent_topic_id` + indexes |
| 2 | `TopicModel` + `topics_api` / repository | create + fetch children |
| 3 | `SubjectDetailController` parent mode + realtime filter | |
| 4 | Route: tap topic → subtopic screen (same UI) | Desktop pane + phone |
| 5 | Topic card: Complete vs progress ring + center % | Parent Done filter logic |
| 6 | Subject progress % includes subtopics | |
| 7 | Today/Missed/Upcoming hierarchy labels | |
| 8 | Voice tools + “add subtopics?” prompt | Parent never in revision tools |
| 9 | Routine / getAllData subtopic names | |
| 10 | Analyze, build web, deploy (existing Vercel aliases) | No git push unless you say |

---

## 11. Decisions (updated / locked)

1. **Always open subtopics on topic tap** even when empty? → **Yes**.  
2. Parent “done”? → **All subtopics: first-read + all 6 revisions** (regular process). **Not** first-read-only.  
3. Parent in **Revision**? → **Never.** Directly **Done** when all subtopics fully done; else **ring + %**.  
4. Max hierarchy depth? → **One level**.  
5. Parent ring %? → **Average of subtopic completion** (`totalRevisions/6` after first-read; 0 before).  

---

## 12. Out of scope (this plan)

- Infinite nesting  
- Separate subtopic revision UI chrome beyond reused cards  
- Changing Day 1/3/7/14/30/90 schedule math  
- Git commit / Vercel deploy until you approve implementation

---

## 13. Next step

**Approve this plan** (or adjust decisions in §11), then implement Steps 1–10 in order, reusing `SubjectDetailScreen` + existing topic widgets + a parent-aware controller.
