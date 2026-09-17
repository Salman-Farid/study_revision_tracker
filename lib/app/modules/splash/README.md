# splash

Boot splash and initial routing.

```
splash/
├── splash_screen.dart          # UI shell
├── splash_controller.dart      # GetX state + actions
├── splash_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `splash_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `splash_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  splash_screen.dart
  widgets
```
