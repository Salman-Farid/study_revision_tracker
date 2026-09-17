# Code Reusability Audit — `lib/`

**Scope:** full `lib/` tree · **Mode:** audit only — **no code changed**  
**Goal:** one place per pattern so a developer can fix/add/delete once and reuse everywhere, without changing functionality or UI.

How to use this file:
1. Find the pattern in **Duplication found**.
2. Open the listed **canonical** file.
3. See **Can be used in** for call sites that could adopt it later.

---

## Executive summary

| Priority | Opportunity | Repeated in | Suggested home |
|----------|-------------|-------------|----------------|
| P0 | Chat bubble set (system/user/assistant/thinking) | 2 full copies | `voice_assistant/widgets/shared/chat_bubbles.dart` |
| P0 | Voice error bar | 2 full copies | `voice_assistant/widgets/shared/error_bar.dart` |
| P0 | 12-hour time formatter | **5 implementations** | `app/domain/routine/routine_time_utils.dart` (already exists) |
| P1 | Same-calendar-day check | **4+ places** | `app/domain/routine/routine_timeline.dart` |
| P1 | Class weekday matching | 3 ad-hoc copies + 1 domain | `app/domain/routine/class_day_matcher.dart` |
| P1 | Shimmer / skeleton loaders | 5 loaders + 1 shared | `app/widgets/skeleton_loader.dart` |
| P1 | Empty states | 2 widget families | `app/widgets/empty_state.dart` |
| P2 | Filter chip row | Today + Subject detail | `app/widgets/filter_chip_row.dart` |
| P2 | White surface card chrome | ~91 `BoxDecoration` radius usages | `app/theme/app_theme.dart` extensions |
| P2 | Snackbar helpers | **57** `Get.snackbar` call sites | `app/core/utils/snackbars.dart` |
| P3 | Status badges / day pills | several private widgets | `app/widgets/status_badge.dart` |

**Existing shared library (already good — expand it):**

| File | Widget | Currently used in |
|------|--------|-------------------|
| `lib/app/widgets/empty_state.dart` | `EmptyState` | today, subject_detail, subjects |
| `lib/app/widgets/stat_card.dart` | `StatCard` | dashboard stats grid |
| `lib/app/widgets/skeleton_loader.dart` | `SkeletonGrid` | (available; not widely used yet) |
| `lib/app/widgets/revision_schedule_timeline.dart` | timeline UI | subject/topic revision UI |
| `lib/app/theme/app_theme.dart` | `AppColors`, `AppTextStyles`, `S` (in constants) | everywhere |
| `lib/app/domain/routine/routine_timeline.dart` | `RoutineTimeline`, `RoutineTimelineItem` | dashboard |
| `lib/app/domain/routine/class_day_matcher.dart` | `ClassDayMatcher` | widget data |
| `lib/app/domain/routine/routine_time_utils.dart` | `formatTime12Hour`, `isSameCalendarDay` | routine controller |

---

## P0 — Copy-paste duplicates (highest leverage)

### 1. Voice chat bubbles (two full private trees)

| File | Private classes |
|------|-----------------|
| `lib/gemini_3_flash_live_voice_chatbot/features/voice_assistant/widgets/full_screen/chat_bubbles.dart` | `_ChatBubble`, `_SystemBubble`, `_UserBubble`, `_AssistantBubble`, `_ThinkingBubble` |
| `lib/gemini_3_flash_live_voice_chatbot/features/voice_assistant/widgets/floating_dialogue/chat_bubbles.dart` | **same five class names** |

**Used by:**
- `voice_assistant_screen.dart` (part → full_screen)
- `study_assistant_dialogue.dart` (part → floating_dialogue)

**Reuse:** extract public `ChatBubble`, `SystemChatBubble`, `UserChatBubble`, `AssistantChatBubble`, `ThinkingChatBubble` into  
`widgets/shared/chat_bubbles.dart`. Both UIs import that folder.  
*Visuals can stay identical via shared params (compact vs dense padding).*

---

### 2. Voice error bar

| File | Class |
|------|-------|
| `.../widgets/full_screen/error_bar.dart` | `_ErrorBar` |
| `.../widgets/floating_dialogue/error_bar.dart` | `_ErrorBar` |

**Reuse:** one `VoiceErrorBar` under `widgets/shared/`.

---

### 3. 12-hour clock formatting (5 copies)

| File | API |
|------|-----|
| **Canonical** `lib/app/domain/routine/routine_time_utils.dart` | `formatTime12Hour(String time24)` |
| **Canonical** `lib/app/domain/routine/routine_timeline.dart` | `RoutineTimeline.to12Hour(int hour, int minute)` |
| `lib/app/core/services/notifications/format_clock.dart` | `formatTime12(int hour, int minute)` |
| `lib/app/core/services/widget_data/format_utils.dart` | `_formatTime12(int hour, int minute)` |
| Inline in `notifications/*` and routine code | `period = hour >= 12 ? 'PM' : 'AM'` |

**Can be used in:**
- `notifications/daily_schedule.dart`
- `widget_data/daily_routine_fetch.dart`
- `routine_controller.dart` (already uses domain helper — good)
- Any future “show time” UI

**Reuse:** one public API in `routine_time_utils.dart` (e.g. `formatHm12(int hour, int minute)` + keep `formatTime12Hour`); notifications/widgets import `domain/` instead of private copies.

---

## P1 — Domain logic duplicated outside `domain/`

### 4. Same calendar day

| File | Pattern |
|------|---------|
| **Canonical** `domain/routine/routine_timeline.dart` | `RoutineTimeline.sameDay` |
| **Canonical** `domain/routine/routine_time_utils.dart` | `isSameCalendarDay` |
| `core/services/notifications/bulk_reschedule.dart` | inline `year/month/day` triple compare |
| `core/services/notifications/revision_schedule.dart` | inline triple compare |
| `voice_assistant/.../tools_subject_read.dart` | likely similar |

**Can be used in:** all notification scheduling, voice tools, dashboard, calendar.

---

### 5. “Does this class run on day X?”

| File | Status |
|------|--------|
| **Canonical** `domain/routine/class_day_matcher.dart` | `ClassDayMatcher.matchesDay` |
| `widget_data/class_routine_fetch.dart` | delegates to domain — **good** |
| `notifications/class_schedule.dart` | partial: `dates` + `recurringDays` only |
| `notifications/bulk_reschedule.dart` | partial inline |
| `voice_assistant/controller/tools_subject_read.dart` | partial (`recurringDays.contains`) |

**Can be used in:** every class-routine consumer. Prefer domain helper so ISO dates / weekday names / numeric weekdays stay consistent.

---

### 6. Shimmer loaders

| File | Class |
|------|-------|
| `lib/app/widgets/skeleton_loader.dart` | `SkeletonGrid` **(shared)** |
| `modules/dashboard/widgets/dashboard_header.dart` | `DashboardShimmerLoader` |
| `modules/routine/widgets/routine_shimmers.dart` | `DailyShimmer`, `ClassShimmer` |
| `modules/statistics/widgets/statistics_shimmer.dart` | `StatisticsShimmerLoader` |
| `modules/subjects/widgets/subjects_grid.dart` | inline `Shimmer.fromColors` |

**Reuse:** extend `skeleton_loader.dart` with `SkeletonList`, `SkeletonCard`, `SkeletonRow` and keep thin per-screen wrappers if layout differs.

---

### 7. Empty / “nothing here” UI

| File | Class | Used in |
|------|-------|---------|
| **Canonical** `app/widgets/empty_state.dart` | `EmptyState` | today, subject_detail, subjects |
| `modules/statistics/widgets/statistics_streak_card.dart` | `StatisticsEmptyState` | statistics charts/insights |
| Routine daily empty | inline `Center` + icon + text | `routine/widgets/routine_bodies.dart` |

**Reuse:** map `StatisticsEmptyState` → `EmptyState(title, subtitle)` or add optional `icon`/`d` params so stats can drop the private class.

---

## P2 — UI chrome patterns (style consistency, not 1:1 clones)

### 8. Filter chips

| File | Classes |
|------|---------|
| `modules/today/widgets/today_filter_chips.dart` | `TodayFilterChips`, `TodayChip` |
| `modules/subject_detail/widgets/subject_filter_chips.dart` | subject filter chips |

**Reuse:** `app/widgets/filter_chip_row.dart` with `label`, `selected`, `onTap`, `color`.  
**Can be used in:** Today, Subject detail, Routine mode toggle (visual only), Revision widget promo N/A.

---

### 9. White / bordered surface card

Roughly **91** radius-bound `BoxDecoration` / card containers across modules (dashboard hero, daily routine live card, promo cards, settings rows, etc.).

**Canonical styles:** `app/theme/app_theme.dart` (`AppColors.surface`, `border`, `radius` via `S`).

**Reuse:** `AppTheme` / extension helpers e.g. `AppSurfaces.card(d)`, `AppSurfaces.hero(d)` — call sites keep layout; only extract decoration.

---

### 10. Status badges / pills

| File | Classes |
|------|---------|
| `modules/routine/widgets/revision_card_parts.dart` | `RevisionChip`, `DayBadge`, `CardStatusIndicator`, `CardStatusText` |
| `modules/subject_detail/widgets/topic_card_badges.dart` | topic badges |
| `modules/today/widgets/today_revision_tile.dart` | inline status styling |

**Reuse:** `app/widgets/status_badge.dart` (`label`, `color`, `filled` / outline).

**Can be used in:** Today tiles, Routine revision cards, Subject detail topic rows, Calendar day dots.

---

### 11. Snackbars

**57** `Get.snackbar(...)` call sites (errors, success, tool failures).

**Reuse:** `app/core/utils/snackbars.dart`  
`AppSnack.error(message)`, `AppSnack.success(message)`, `AppSnack.info(message)`  
so duration/colors/position stay identical everywhere.

---

### 12. Loading button / spinner

**18** `CircularProgressIndicator` usages (buttons, overlays, dialog actions).

**Reuse:** `app/widgets/loading_button.dart` or `AppLoading.indicator()` if dimensions/colors match.

---

## P3 — Controller / service patterns

### 13. Silent realtime refresh (debounce)

| File | Pattern |
|------|---------|
| `modules/dashboard/dashboard_controller.dart` | listen streams → 400ms debounce → reload |
| `modules/today/today_controller.dart` | similar |
| `modules/subject_detail/controller_parts/realtime.dart` | similar |
| `data/services/supabase_service.dart` | `_debouncedWidgetUpdate` / notification |

**Reuse:** `app/core/utils/debounced.dart` or a tiny mixin `DebouncedRefresh`.

---

### 14. Voice tool registration (already documented)

| Step | File |
|------|------|
| Schema | `voice_assistant/controller/tools_definition.dart` |
| Handler | `voice_assistant/controller/tools_*.dart` |
| Dispatch | `voice_assistant/controller/tool_dispatch.dart` |

Mic timing knobs: `voice_assistant/controller/mic_state.dart` (`_kUnmuteDebounce`, `_kEchoGuardWindow`, `_kMicReconcilePeriod`).

---

## Inventory — shared widgets today

| Path | Public widget(s) | Safe reuse targets |
|------|------------------|--------------------|
| `app/widgets/empty_state.dart` | `EmptyState` | All “no data” screens |
| `app/widgets/stat_card.dart` | `StatCard` | Dashboard, settings `MiniStat`, future KPI grids |
| `app/widgets/skeleton_loader.dart` | `SkeletonGrid` | Any grid loading |
| `app/widgets/revision_schedule_timeline.dart` | timeline | Subject/topic revision UIs |
| `app/modules/subject_detail/widgets/expandable_card.dart` | `ExpandableCard`, `AnimatedExpanded` | Any collapsible section |
| `gemini…/widgets/shared/mic_button.dart` | `MicButton` | Full screen + floating dialogue |
| `gemini…/widgets/shared/wave_animation.dart` | `WaveAnimation` | Both voice UIs |
| `gemini…/shared/widgets/thinking_dots.dart` | thinking dots | Voice + dialogue |

---

## Suggested extraction order (when you choose to implement)

1. **Voice shared chat + error bar** — pure file move, biggest literal clone.  
2. **Time + day helpers → domain** — notifications + widgets import domain; no UI change.  
3. **Shimmer + EmptyState consolidation** — optional visual parity via same parameters.  
4. **FilterChipRow + StatusBadge** — thin wrappers over existing private widgets.  
5. **Snackbar + card chrome helpers** — style-only; highest “don’t search forever” win.

---

## What NOT to merge (avoid over-abstraction)

| Keep separate | Why |
|---------------|-----|
| `VoiceAssistantScreen` vs `StudyAssistantDialogue` | Different chrome, resize, lifecycle |
| Dashboard hero vs promo cards | Different interaction |
| Module `controller_parts/` tool files | Already single-responsibility |
| Translation maps per language | Intentional file-per-locale |
| Native Android widget Kotlin vs Flutter | Platform boundary |

---

## Quick “where do I edit?” index for reuse work

| Change | File to start from |
|--------|-------------------|
| Shared empty UI | `lib/app/widgets/empty_state.dart` |
| Shared loading skeleton | `lib/app/widgets/skeleton_loader.dart` |
| Shared KPI card | `lib/app/widgets/stat_card.dart` |
| Time / date math | `lib/app/domain/routine/` |
| Theme tokens | `lib/app/theme/app_theme.dart` |
| Voice chat look | `gemini…/voice_assistant/widgets/` |
| Voice tools / mic | `gemini…/voice_assistant/controller/` |

---

*Generated as a read-only audit. Implement in small PRs; run `flutter analyze` + `flutter test` after each extraction.*
