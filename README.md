# ispotipay

Lightweight, ad-free personal music player inspired by Spotify & YouTube Music with synchronized scrolling lyrics and offline downloads.

**Status:** In Development · **Platform:** Android, iOS, Windows, Linux, macOS · **Last verified setup:** 2026-10-29

---

## 1. What it does

- **100% Free & Ad-Free Music Streaming**: Streams audio-only data directly without video overhead.
- **Synchronized Lyrics (Karaoke-Style)**: Real-time scrolling and highlighted lyrics powered by LRCLIB.
- **Offline Downloads with Lyrics**: Download songs alongside companion `.lrc` lyrics files for zero-internet playback.
- **Local-First Privacy**: Favorites and Recent listening history are strictly stored on-device via SQLite.
- **Low-End Hardware Optimization**: Strict memory budgeting, 25-item chunk pagination, and 400ms search debounce.

---

## 2. Tech Stack

- **Framework:** Flutter (Material 3 Dark Minimalist)
- **Language:** Dart `^3.12.0`
- **Audio Engine:** `just_audio` + `audio_service`
- **Stream Provider:** `youtube_explode_dart`
- **Lyrics Provider:** LRCLIB REST API + Local LRC parser
- **Database:** Local SQLite (`sqflite` + `sqflite_common_ffi`)
- **Storage:** Local Device Storage (`path_provider`)

---

## 3. Quickstart & Verification

```bash
# 1. Install dependencies
flutter pub get

# 2. Run static analyzer
flutter analyze

# 3. Run tests
flutter test

# 4. Launch app
flutter run
```
