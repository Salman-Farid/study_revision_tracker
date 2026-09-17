# App core (`lib/app/core`)

| Folder | What lives here |
|--------|-----------------|
| `bootstrap/` | Startup steps called from `main.dart` (platform, DI, widgets) |
| `constants/` | AppConstants (Supabase keys), sizes, responsive |
| `localization/` | `AppTranslations` + `translations/<lang>.dart` |
| `services/` | Notifications, widgets, password recovery, connectivity |
| `web/` | Web-only helpers |
| `widgets/` | Tiny shared UI helpers (if any) |

**Startup order** is defined in `main.dart` and `bootstrap/service_registration.dart` — change order there only.
