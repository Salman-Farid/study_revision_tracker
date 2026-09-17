# today

Today tab: due / missed revisions.

```
today/
├── today_screen.dart          # UI shell
├── today_controller.dart      # GetX state + actions
├── today_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `today_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `today_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  today_binding.dart
  today_controller.dart
  today_revisions_screen.dart
  widgets
```
