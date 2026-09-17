# topic_detail

Single topic detail (if used).

```
topic_detail/
├── topic_detail_screen.dart          # UI shell
├── topic_detail_controller.dart      # GetX state + actions
├── topic_detail_binding.dart         # (optional) GetX DI
├── widgets/                    # private widgets for this screen
└── controller_parts/           # (optional) extra controller logic
```

| Change this… | Edit |
|--------------|------|
| Layout / copy / colors on this screen | `topic_detail_screen.dart` or `widgets/` |
| Loading, taps, data refresh | `topic_detail_controller.dart` or `controller_parts/` |
| Shared look (all screens) | `../../theme/` |
| Shared Supabase query | `../../data/` |

Actual files:
```
  topic_detail_binding.dart
  topic_detail_controller.dart
  topic_detail_screen.dart
```
