# APK Size Cleanup — Scan Report

**Date:** project rescan · **Goal:** smallest production APK without changing product behavior used today.

---

## 1. Root junk (not in APK, ~32 MB on disk)

| Path | Size | Action |
|------|------|--------|
| `goose-aarch64-apple-darwin.tar.bz2` | **32 MB** | Delete (binary tarball, unrelated to app) |
| `.crush/` | ~0.3 MB | Local tool DB — leave or ignore |
| `android/.gradle/` | build cache | Regenerated; not shipped |

---

## 2. Unused Dart files (delete)

| File | Why |
|------|-----|
| `lib/gemini_3_flash_live_voice_chatbot/features/voice_assistant/widgets/shared/mic_button.dart` | `MicButton` never imported / constructed |
| `lib/gemini_3_flash_live_voice_chatbot/features/voice_assistant/widgets/shared/wave_animation.dart` | `WaveAnimation` never imported / constructed |
| `lib/app/data/services/calendar_service.dart` | `CalendarService` never referenced |
| `lib/app/widgets/filter_chip.dart` | Shared `FilterChipBadge` unused — subject screen has its own private copy |

**Keep (intentional API, not yet wired everywhere):**
- `lib/app/core/utils/snackbars.dart` (`AppSnack`) — documented in reuse audit
- `lib/app/widgets/status_badge.dart`, `skeleton_loader.dart`, `card_empty_state.dart` — used

---

## 3. Unused pubspec dependencies (remove)

| Package | Evidence |
|---------|----------|
| `cupertino_icons` | No `CupertinoIcons` in `lib/` |
| `path_provider` | No imports |
| `permission_handler` | No imports |
| `just_audio` | Custom `PcmAudioPlayer` used instead |

**Used (keep):** get, supabase_flutter, app_links, fl_chart, intl, uuid, connectivity_plus, flutter_local_notifications, timezone, google_generative_ai, table_calendar, speech_to_text, shimmer, record, web_socket_channel, device_calendar, shared_preferences, google_sign_in, flutter_sound, flutter_reorderable_grid_view, home_widget, flutter_timezone, workmanager, http, web.

---

## 4. Assets

| Asset | Size | Used? | Action |
|-------|------|-------|--------|
| `assets/images/auth_study.png` | **1.9 MB** (1024×1536 PNG) | Yes (`auth_image_pane`, `about_intro_cards`) | **Compress** (JPEG/WebP or smaller PNG) — largest APK win |
| `assets/fonts/NotoSansBengali.ttf` | 456 KB | Yes (pubspec + Bengali UI) | Keep |
| `assets/images/.gitkeep`, `assets/icons/.gitkeep` | 0 | placeholders | Keep or drop empty dirs |
| `assets/icons/` | empty | — | Can drop folder from pubspec if always empty |

Pubspec lists both `assets/images/` **and** `assets/images/auth_study.png` (redundant). Keep folder only.

---

## 5. Android release (biggest APK lever after assets)

`android/app/build.gradle.kts` currently:
- No `minifyEnabled` / `shrinkResources`
- No ABI splits / `--split-per-abi`

**Recommended (release only):**
```kotlin
buildTypes {
  release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    // … keep debug signing for now or add real signing
  }
}
```

Build with:
```bash
flutter build apk --release --split-per-abi
# or
flutter build appbundle --release
```

**Note:** Some Flutter plugins need ProGuard keep rules — test a release install after enabling minify.

---

## 6. Expected impact (order of magnitude)

| Step | APK impact |
|------|------------|
| Compress `auth_study.png` 1.9 MB → ~150–300 KB | **−1.5 MB+** |
| Remove 4 unused plugins | smaller dependency graph / native libs |
| `--split-per-abi` | often **−40–50%** vs universal APK |
| `minify + shrinkResources` | **−10–30%** DEX/resources |
| Delete 32 MB tarball | disk only (not APK) |

---

## 7. Not deleted (still needed)

- `google_generative_ai` — `GeminiService`
- `device_calendar` — used in app
- `flutter_sound` / `record` — audio
- All supabase / notifications / home_widget packages
- `CODE_REUSABILITY_AUDIT.md` / READMEs — docs
