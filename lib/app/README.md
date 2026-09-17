# App architecture (`lib/app`)

GetX feature-first layout. Each module owns its UI + controller + optional widgets.

```
lib/app/
├── core/
│   ├── bootstrap/          # app startup steps (main.dart calls these in order)
│   ├── constants/          # colors, sizes, supabase keys
│   ├── localization/       # AppTranslations + translations/<lang>.dart
│   ├── services/           # notifications, widgets, password recovery
│   └── utils/
├── data/
│   ├── models/             # DTOs (Subject, Topic, DailyRoutine, …)
│   ├── repositories/       # thin wrappers over SupabaseService
│   └── services/           # SupabaseService (+ supabase/*_api parts)
├── domain/routine/         # pure logic (timeline, day matcher) — easy to unit test
├── modules/<feature>/
│   ├── <feature>_screen.dart
│   ├── <feature>_controller.dart
│   ├── controller_parts/   # large controllers split by responsibility
│   └── widgets/            # private widgets for that screen only
├── routes/                 # AppRoutes / AppPages
├── theme/                  # AppColors, AppTextStyles
└── widgets/                # app-wide widgets (promo dialog, …)
```

## Rules of thumb

| Do | Don't |
|----|--------|
| Keep screen shells small; extract sections to `widgets/` | Put business logic in `build()` |
| Put shared pure logic in `domain/` | Import `dart:io` in code used by web |
| Extend big services via `part` + `extension` in a subfolder | Duplicate Supabase queries in UI |
| Use `debugPrint` | Use `print` |

## Home screen widgets (Android)

Native widgets live under `android/.../kotlin/com/example/study_revision_tracker/`.
Flutter feeds them via `core/services/widget_data_service.dart` + `widget_data/` parts.
