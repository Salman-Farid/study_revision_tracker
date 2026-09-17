# statistics

History tab: streak, charts, insights.

```
statistics/
├── statistics_screen.dart          # UI shell
├── statistics_controller.dart      # GetX state + actions
├── statistics_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `statistics_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `statistics_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  statistics_binding.dart
  statistics_controller.dart
  statistics_screen.dart
  widgets
```
