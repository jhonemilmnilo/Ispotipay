# PROJECT_BRIEF: ispotipay

> Source of truth for what we are building, why, and for whom.
> Keep it up to date. When scope changes, update this document first.

---

## 1. Vision and Goals

- **What is it?**
  A lightweight, ad-free, personal music streaming and offline player inspired by Spotify and YouTube Music. Built with Flutter for smooth performance even on low-end devices.
- **Why build it?**
  To enjoy seamless personal music streaming without subscription fees or ads, with full offline capabilities including synchronized karaoke-style highlighted lyrics, and zero cloud lock-in for personal listening history.
- **Target user:**
  Personal use (power music listeners on mobile/desktop who value privacy, offline listening with lyrics, and lightweight battery/data efficiency).
- **Core value proposition:**
  - 100% Free & Ad-free music streaming & downloading.
  - Offline mode with offline synchronized scrolling lyrics (karaoke style).
  - 100% Local-first data: Favorites and Recent listening history are stored only on device (no remote tracking/server needed).
  - Optimized for low-end devices: minimal RAM footprint, lightweight UI animations, and efficient audio streaming.

---

## 2. Core Features (MVP)

1. **Music Discovery & Search:**
   - Search songs, artists, and albums.
   - Top Charts & Trending Music feed fetched from public music charts.
2. **Audio Streaming & Background Playback:**
   - Stream audio-only tracks (low data consumption).
   - Full playback controls with notification & lock screen controls (`audio_service`).
3. **Synchronized Karaoke-Style Lyrics:**
   - Real-time timestamp-synced highlighted lyrics (LRC format via open APIs like LRCLIB).
   - Auto-scrolling synced with current playback position.
4. **Offline Download Engine:**
   - Download audio file to local storage.
   - Automatically download and bundle the companion `.lrc` lyrics file.
   - Seamless offline playback with full synced lyrics when disconnected.
5. **Local-First Library:**
   - **Favorites**: Stored locally in on-device storage (Hive/SQLite).
   - **Recent History**: Stored locally on device.
   - **Downloads**: View and manage all downloaded tracks.

---

## 3. Non-Goals (Out of Scope for MVP)

- User account creation, remote login, or cloud sync across devices (Local-first only).
- Social features (friends list, sharing to feed, collaborative playlists).
- Heavy 3D visualizers or canvas animations that lag budget devices.
- In-app ads, subscription paywalls, or analytics trackers.

---

## 4. Quality & Performance Requirements

- **Low-end Device Optimization:** RAM usage strictly managed; lazy-loading for long lists; dark theme with high contrast and zero GPU-heavy blur effects.
- **Offline First:** Playback of downloaded files must work without any internet handshake or remote ping.
- **Audio Stutter Prevention:** Pre-buffering and local file caching.
