# dashboard

Home tab: hero card, stats, live daily-routine card.

```
dashboard/
├── dashboard_screen.dart          # UI shell
├── dashboard_controller.dart      # GetX state + actions
├── dashboard_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `dashboard_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `dashboard_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  dashboard_binding.dart
  dashboard_controller.dart
  dashboard_screen.dart
  widgets
```
