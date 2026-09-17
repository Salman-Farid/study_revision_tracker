# subject_detail

One subject: topics, first-read, revisions.

```
subject_detail/
├── subject_detail_screen.dart          # UI shell
├── subject_detail_controller.dart      # GetX state + actions
├── subject_detail_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `subject_detail_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `subject_detail_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  controller_parts
  subject_detail_binding.dart
  subject_detail_controller.dart
  subject_detail_screen.dart
  widgets
```
