# routine

Daily routine + class routine tabs (and revision cards).

```
routine/
├── routine_screen.dart          # UI shell
├── routine_controller.dart      # GetX state + actions
├── routine_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `routine_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `routine_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  routine_binding.dart
  routine_controller.dart
  routine_item_model.dart
  routine_screen.dart
  widgets
```
