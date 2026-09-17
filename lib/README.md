# Smart Revision Tracker — code map

**Want to change something? Search this table first. Go to that folder. Do not hunt across the app.**

| I want to… | Go to |
|------------|--------|
| Add / change a **voice AI tool** (mic “add a subject”, etc.) | `gemini_3_flash_live_voice_chatbot/features/voice_assistant/` → README + `controller/tool_dispatch.dart` |
| Fix **mic on/off timing** | `…/voice_assistant/controller/mic_state.dart` (constants at top) |
| Change **Gemini model / API key / voice** | `gemini_3_flash_live_voice_chatbot/config/gemini_config.dart` |
| Edit **WebSocket protocol** | `gemini_3_flash_live_voice_chatbot/core/websocket/` |
| Add a **language** | `app/core/localization/translations/` + register in `app_translations.dart` |
| Change **notification** channels / schedule times | `app/core/services/notifications/` |
| Change **home-screen widget** data (Android) | `app/core/services/widget_data/` |
| Change **password reset** flow | `app/core/services/password_recovery/` |
| Change **Supabase queries** (CRUD) | `app/data/services/supabase/` |
| Add a **DB model field** | `app/data/models/` then update matching `*_api.dart` |
| Add a **route** | `app/routes/` |
| Change **theme colors / text styles** | `app/theme/` |
| Change **app startup order** | `app/core/bootstrap/` + `main.dart` |
| Edit a **screen UI** | `app/modules/<feature>/<feature>_screen.dart` + that module’s `widgets/` |
| Edit a **screen logic** | `app/modules/<feature>/<feature>_controller.dart` + `controller_parts/` |
| Pure **date/timeline math** | `app/domain/` |

## Top-level layout

```
lib/
├── main.dart                          # thin: call bootstrap helpers, runApp
├── app/                               # product app (GetX modules)
│   ├── core/                          # bootstrap, constants, localization, services
│   ├── data/                          # models, repositories, Supabase
│   ├── domain/                        # pure, testable logic
│   ├── modules/                       # one folder per screen/feature
│   ├── routes/                        # named routes
│   ├── theme/                         # AppColors / AppTextStyles
│   └── widgets/                       # widgets shared across modules
└── gemini_3_flash_live_voice_chatbot/ # AI voice package (import gemini_chatbot.dart)
```

## Module pattern (`app/modules/<name>/`)

| File | Role |
|------|------|
| `<name>_screen.dart` | Screen shell (keep small) |
| `<name>_controller.dart` | GetX controller shell |
| `<name>_binding.dart` | GetX binding |
| `widgets/` | Private UI pieces for this screen only |
| `controller_parts/` | Extra logic when the controller grows |

## Service pattern

Large services are **one public class** + sibling folder of `part` files:

- `notification_service.dart` + `notifications/*`
- `widget_data_service.dart` + `widget_data/*`
- `password_recovery_service.dart` + `password_recovery/*`
- `data/services/supabase_service.dart` + `supabase/*_api.dart`

Call sites stay `Get.find<X>()` / static methods — only the implementation files move.

## Tests

`test/` — pure domain tests (`routine_timeline`, `class_day_matcher`, password recovery).
Run: `flutter test`
