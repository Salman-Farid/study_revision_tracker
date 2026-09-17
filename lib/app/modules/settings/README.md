# settings

App settings + About panel.

```
settings/
├── settings_screen.dart          # UI shell
├── settings_controller.dart      # GetX state + actions
├── settings_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `settings_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `settings_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  about_this_app_panel.dart
  settings_controller.dart
  settings_screen.dart
  widgets
```
