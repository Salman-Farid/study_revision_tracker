# calendar

Month view of revisions and classes.

```
calendar/
├── calendar_screen.dart          # UI shell
├── calendar_controller.dart      # GetX state + actions
├── calendar_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `calendar_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `calendar_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  calendar_binding.dart
  calendar_controller.dart
  calendar_screen.dart
```
