# TASKS: ispotipay

> Single source of truth for all current and upcoming work.
> Update this file as tasks start, finish, or change priority.

---

## 1. Roadmap & Epics

- [ ] **Epic 1: Project Foundations & Core Dependencies** (In Progress)
  - Initialize Git & verify clean build
  - Add core audio, storage, and networking dependencies
- [ ] **Epic 2: Local Storage Engine (Favorites & Recents)**
  - Implement Hive/local DB service for local-first storage
  - Save/fetch favorites and history locally
- [ ] **Epic 3: Audio Streaming & Player Service**
  - Setup `just_audio` background audio service
  - Mini-player & Full Player screen with smooth seekbar
- [ ] **Epic 4: Synchronized Scrolling Lyrics (Online & Offline)**
  - LRCLIB API client
  - LRC timestamp parser (`[mm:ss.xx]`)
  - Spotify-style lyrics auto-scroll & active line highlighter widget
- [ ] **Epic 5: Offline Download Manager (Audio + Synced Lyrics)**
  - Download track stream to disk
  - Fetch and save accompanied `.lrc` file to local storage
  - Offline mode auto-switch
- [ ] **Epic 6: Discovery & Search (Top Charts & Trending)**
  - YouTube Music / iTunes Charts trending tracks integration
  - Search query suggestions and results list
- [ ] **Epic 7: Low-End Device Optimization & Performance Polish**
  - RAM profiling, image caching optimization, high-contrast dark theme

---

## 2. Current Focus

- **Current Task:** Setup core dependencies (`just_audio`, `audio_service`, `hive`, `http`, etc.) and establish local database service for Favorites & Recents.

---

## 3. Session Handoff

- **Nasaan tayo:** Defined project brief, architecture, and agent specifications. Validated local-first storage requirement for Favorites and Recents, offline audio + synced LRC lyrics, and low-end hardware optimization.
- **Susunod na hakbang:** 
  1. Initialize Git (`git init`) and create first commit.
  2. Add dependencies to `pubspec.yaml` with user approval.
