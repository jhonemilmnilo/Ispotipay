# AGENTS.md: Project Rules

> Project-specific instructions for AI agents. Global rules in `GEMINI.md` still apply.
> Keep this file short and accurate. Update it whenever the stack, commands, or structure change.

---

## 1. Project overview

- **Name:** ispotipay
- **What it does:** Lightweight, ad-free personal music player with online streaming, Spotify-style synchronized scrolling lyrics, offline downloads (audio + synced lyrics), and local-only favorites and recent history.
- **Who uses it:** Personal use on mobile and desktop devices, heavily optimized for low-end hardware.
- **Status:** MVP in progress
- **Details:** see `PROJECT_BRIEF.md` (goals, features, scope) and `ARCHITECTURE.md` (structure, data flow).
- **Current work:** see `TASKS.md`.

## 2. Tech stack

| Layer | Choice | Version |
|-------|--------|---------|
| Language | Dart | ^3.12.0 (SDK) |
| Framework | Flutter | Stable |
| UI / Styling | Flutter Material 3 (Dark Minimalist) | Flutter built-in |
| Database | Local Relational DB (`sqflite` + `sqflite_common_ffi`) | Latest compatible |
| Audio Playback | `just_audio` + `audio_service` | Latest compatible |
| Lyrics Provider | LRCLIB API & Local LRC Parser | REST / Local file |
| File storage | Device Documents Directory (`path_provider`) | Local only |
| Hosting / Deploy | Local install / APK export | Local only |
| Package manager | flutter pub | Native |
| Testing | `flutter_test` | Flutter built-in |

**Rules about the stack:**
- Use only the stack above. Do not introduce alternative audio frameworks without permission.
- Check the installed version before using any API.
- Use `flutter pub` only.

## 3. Commands

Run these from the project root. Always use these exact commands:

| Purpose | Command |
|---------|---------|
| Install dependencies | `flutter pub get` |
| Run dev server / app | `flutter run` |
| Build APK | `flutter build apk --release` |
| Build Windows | `flutter build windows` |
| Run all tests | `flutter test` |
| Run one test file | `flutter test test/<test_file>_test.dart` |
| Lint / Analyze | `flutter analyze` |
| Format | `dart format .` |

- If a command above is marked n/a, skip it and tell me instead of inventing one.

## 4. Folder structure

```
ispotipay/
├── lib/
│   ├── main.dart             # App entry point & initialization
│   ├── models/               # Track, LyricLine, Playlist models
│   ├── services/             # Audio, Lyrics, Download, Storage services
│   ├── providers/            # State management (Player, Library, Lyrics)
│   └── ui/                   # Screens (Home, Player, Library, Search) & widgets
├── assets/                   # Static icons and fallback images
├── test/                     # Unit and widget tests
├── .agent/                   # Agent rules and automated workflows
│   ├── rules/                # Code-style, security rules
│   └── workflows/            # Playbooks (start_session, new_feature, etc.)
└── AGENTS.md                 # This file
```

## 5. Conventions

**Naming**
- Files: `snake_case.dart`
- Classes / Types: `PascalCase`
- Variables / Functions: `camelCase`
- Constants: `lowerCamelCase` or `UPPER_SNAKE_CASE`

**Code style**
- Strict lints enabled via `flutter_lints`.
- Performance first: Avoid deep widget trees, use `const` constructors wherever possible.
- Avoid memory leaks: Always dispose audio player controllers and stream subscriptions.

**Data & Privacy**
- Favorites and Recents must NEVER leave the device. Stored locally only.
- Audio files and lyrics files stored with safe clean filenames.

## 6. Definition of done

A task is done only when:
1. Feature works smoothly as described.
2. `flutter analyze` and `flutter test` pass with no errors or warnings.
3. No unnecessary memory overhead or stutter on low-end hardware.
4. `TASKS.md` is updated.
