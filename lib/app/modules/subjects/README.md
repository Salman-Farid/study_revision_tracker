# subjects

Subjects grid + progress.

```
subjects/
├── subjects_screen.dart          # UI shell
├── subjects_controller.dart      # GetX state + actions
├── subjects_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `subjects_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `subjects_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  controller_parts
  subjects_binding.dart
  subjects_controller.dart
  subjects_screen.dart
  widgets
```
