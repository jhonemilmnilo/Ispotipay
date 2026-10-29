---
description: Wrap up the session safely. Checks the app state, updates TASKS.md handoff, DECISIONS.md, ERRORS_LOG.md and docs, and writes clear notes so a brand-new chat can continue. Use as /end_session before closing the chat.
---

# End Session Workflow

Goal: leave the project in a known state and write down everything a new chat needs, so nothing is lost. Reply in Taglish. Do not commit or push unless I ask.

1. **Check the real state.** Run `git status` and `git diff --stat`. List uncommitted changes. Check whether the app currently builds and runs (or whether it is broken and exactly how).

2. **Recommend what to do with the changes.**
   - If the work is in a good, working state: recommend running `/pre_commit_check`, then committing, and suggest a commit message.
   - If it is half-done or broken: recommend a work-in-progress commit on a branch, or a stash, and clearly say that it is not working. Never leave me with silent broken code.
   - Always tell me the **last working commit** so I can go back to it.

3. **Update `TASKS.md`:**
   - Make sure each task's marker is accurate: `[x]` only if verified, `[~]` for the one in progress, `[!]` for blocked.
   - Add any finished tasks to the **Done log**.
   - Add new ideas to **Backlog** and new problems to **Bugs**. Add blocked items to **Blocked** with the reason and what is needed.
   - Update **Current focus** (steps done, files touched, how to test).
   - **Overwrite the Session handoff completely** with: today's date, what was done, state of the app, last working commit, uncommitted changes, the **exact next step**, what I need to do (e.g. fill `.env`, create a bucket, run a migration), open questions, and warnings.

4. **Update project memory where needed:**
   - `DECISIONS.md`: add entries for any meaningful choices made this session (offer first).
   - `ERRORS_LOG.md`: add entries for problems that were hard to fix or likely to recur (offer first; redact secrets).
   - `ARCHITECTURE.md`, `AGENTS.md`, `README.md`, `.env.example`: update if the structure, schema, commands, services, or env variables changed.

5. **Show me every proposed change to these files before saving** if it is more than a small factual update (for example, a task marker or a new row in a table). Do not silently rewrite my documents.

6. **Security reminder.** Confirm no secrets were written into any file or chat this session. If any were, tell me to rotate them.

7. **Give me the closing summary** in this format:
   - **Ginawa ngayon:** what was completed
   - **Estado ng app:** working / partial / broken, and why
   - **Git:** last working commit and any uncommitted changes
   - **Susunod na hakbang:** the exact first action for next time
   - **Gagawin ko (user):** things I must do myself
   - **Para sa susunod na chat:** tell me to start with `/start_session`, or say: "Basahin mo ang TASKS.md at ituloy natin."
