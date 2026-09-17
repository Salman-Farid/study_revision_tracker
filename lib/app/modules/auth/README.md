# auth

Sign-in / sign-up / Google login / forgot password UI.

```
auth/
├── auth_screen.dart          # UI shell
├── auth_controller.dart      # GetX state + actions
├── auth_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `auth_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `auth_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  auth_binding.dart
  auth_controller.dart
  auth_screen.dart
  controller_parts
  widgets
```
