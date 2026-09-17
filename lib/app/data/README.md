# Data layer (`lib/app/data`)

```
data/
├── models/           # DTOs (fromJson / toJson)
├── repositories/     # thin GetX-friendly wrappers
└── services/
    ├── supabase_service.dart   # class shell: client, streams, realtime
    ├── supabase/               # one file per table/feature (part files)
    ├── calendar_service.dart
    ├── gemini_service.dart
    └── image_search_service.dart
```

## Add / change a Supabase operation

| Operation | File |
|-----------|------|
| Subjects | `services/supabase/subjects_api.dart` |
| Topics | `services/supabase/topics_api.dart` |
| Revision schedules | `services/supabase/schedules_api.dart` |
| Revision sessions | `services/supabase/sessions_api.dart` |
| Dashboard stats | `services/supabase/stats_api.dart` |
| Class routines | `services/supabase/class_routines_api.dart` |
| Daily routines | `services/supabase/daily_routines_api.dart` |
| Realtime channels / streams | `services/supabase_service.dart` |

Call from UI via `Get.find<SupabaseService>()` or a repository — do not query Supabase from widgets.

## Models

If you add a column, update the matching model **and** any `*_api.dart` that maps it.
