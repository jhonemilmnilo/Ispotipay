# DECISIONS: ispotipay

> Architecture Decision Records (ADRs).
> Log every non-obvious choice here with context, options, decision, and reasons.

---

## 1. Principles for decisions

- **Document the why, not just the what.** Future you will not remember why you picked SQLite or LRCLIB.
- **Record alternatives.** Knowing what was considered and rejected prevents reopening settled debates.
- **Keep it short.** A decision record should take 5 minutes to write and 1 minute to read.

---

## 2. Index

| ID | Date | Decision | Status |
|----|------|----------|--------|
| D-003 | 2026-10-29 | 25-item chunk pagination and 400ms search debounce | Accepted |
| D-002 | 2026-10-29 | Direct YouTube audio stream extraction + LRCLIB synced lyrics | Accepted |
| D-001 | 2026-10-29 | Use SQLite (`sqflite`) for local-first storage instead of Hive | Accepted |

---

## 3. Decision records (newest first)

### D-003: 25-item chunk pagination and 400ms search debounce
- **Date:** 2026-10-29
- **Status:** Accepted
- **Context:** Low-end mobile devices struggle with rendering long lists and high memory spikes when fetching large datasets at once. Unthrottled search inputs also cause excessive API requests and UI stutter.
- **Decision:** Load exactly 25 items on initial load and paginate on scroll; apply 400ms debounce timer to search queries.
- **Reasons:**
  - Prevents garbage collection stutter on 2GB-3GB RAM phones.
  - Eliminates network race conditions and saves device battery.
- **Affects:** UI Lists, Search Screen, `ARCHITECTURE.md`.

### D-002: Direct YouTube audio stream extraction + LRCLIB synced lyrics
- **Date:** 2026-10-29
- **Status:** Accepted
- **Context:** The app needs ad-free, free music streaming, offline downloads, and synchronized highlighted lyrics without requiring paid developer API keys.
- **Decision:** Use `youtube_explode_dart` for direct audio-only stream extraction and `LRCLIB` REST API for synced LRC lyrics.
- **Reasons:**
  - Streams raw audio only (m4a/opus), saving bandwidth and avoiding heavy video elements.
  - Saves `.lrc` companion files locally for offline synchronized playback.
  - 100% free with zero API key dependencies.
- **Affects:** `services/lyrics_service.dart`, `services/download_service.dart`.

### D-001: Use SQLite (`sqflite`) for local-first storage instead of Hive
- **Date:** 2026-10-29
- **Status:** Accepted
- **Context:** The app needs to store Favorites, Recents, and Download index locally on the device with zero cloud tracking.
- **Decision:** Use `sqflite` (and `sqflite_common_ffi` for desktop) instead of Hive.
- **Reasons:**
  - Relational querying and indexing (e.g. `LIMIT 25 OFFSET ?`, `ORDER BY played_at DESC`).
  - ACID reliability against app crashes or unexpected battery drops during downloads.
- **Affects:** `services/database_service.dart`, `models/track.dart`.
