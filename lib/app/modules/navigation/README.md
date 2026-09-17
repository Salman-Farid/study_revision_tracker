# navigation

Shell: bottom nav / side rail / tab switching.

```
navigation/
├── navigation_screen.dart          # UI shell
├── navigation_controller.dart      # GetX state + actions
├── navigation_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `navigation_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `navigation_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  app_side_bar.dart
  main_navigation.dart
  navigation_controller.dart
  widgets
```
