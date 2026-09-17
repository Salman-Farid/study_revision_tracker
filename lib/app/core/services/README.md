# Core services (`lib/app/core/services`)

App-wide services that are not tied to one screen.

| Service | Entry file | Implementation folder | What it owns |
|---------|------------|----------------------|--------------|
| Local notifications | `notification_service.dart` | `notifications/` | Channels, revision/class/daily alarms, rescheduleAll |
| Home-screen widgets | `widget_data_service.dart` | `widget_data/` | Supabase → SharedPreferences → Android/iOS widgets |
| Password recovery | `password_recovery_service.dart` | `password_recovery/` | Deep-link detection, PKCE session, set-password |
| Connectivity | `connectivity_service.dart` | — | Online/offline Rx |
| Web history helper | `web_history_stub.dart` / `web_history_web.dart` | — | Conditional import for `history.replaceState` |

## Notification timings

Open `notification_service.dart` + `notifications/revision_schedule.dart`,
`class_schedule.dart`, `daily_schedule.dart`.
- Class reminder lead time: `class_schedule.dart` (look for “30 minutes”)
- Daily block fire time: `daily_schedule.dart`
- Bulk rebuild: `bulk_reschedule.dart` → `rescheduleAll`

## Widget payload keys

`widget_data/keys.dart` — SharedPreferences key names shared with native Kotlin widgets.
