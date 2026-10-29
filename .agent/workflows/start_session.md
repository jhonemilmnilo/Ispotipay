---
description: Start a new chat with full context. Reads the project docs and TASKS.md handoff, checks the real git and app state, and summarizes where we are and what is next. Use as /start_session at the beginning of every chat.
---

# Start Session Workflow

Goal: rebuild context in a fresh chat so we continue exactly where we stopped, without guessing. Reply in Taglish. Do not change any code in this workflow.

1. **Read the project memory**, in this order, skipping files that do not exist:
   1. `TASKS.md`: Session handoff (Section 3), Current focus (Section 2), Blocked, and Bugs
   2. `AGENTS.md`: stack, commands, conventions
   3. `PROJECT_BRIEF.md`: goals, features, scope
   4. `ARCHITECTURE.md`: structure, schema, services
   5. `DECISIONS.md`: the Index, so you respect past decisions
   6. `ERRORS_LOG.md`: the Prevention checklist and Quick-lookup index
   7. `README.md`: only if setup details are needed

2. **Check the real state** (read-only commands):
   - `git status`, the current branch, and the last few commits (`git log --oneline -5`)
   - Whether there are uncommitted changes
   - Whether dependencies are installed and the app builds or starts (only if I ask you to run it, or if the handoff says it may be broken)

3. **Compare memory with reality.** If the code, branch, or files do not match what the Session handoff says, or any doc is clearly outdated, **tell me** and ask which is right. Do not guess and do not silently edit documents.

4. **If a project file is missing or still full of `[FILL]` placeholders**, tell me which ones and offer to fill them in (propose first, wait for approval).

5. **Give me a short summary** in this format:
   - **Project:** one line on what it is
   - **Nasaan na tayo:** what was done last, and the state of the app (working / partial / broken)
   - **Kasalukuyang task:** the Current focus, or "wala"
   - **Susunod na hakbang:** the exact next step from the handoff, or the next unblocked task
   - **Mga hadlang / bugs:** blocked items and open bugs that matter
   - **Kailangan mula sa iyo:** anything I need to do (e.g. set values in `.env`, run a migration)
   - **Mga tanong:** open questions, if any

6. **Wait for my go-ahead** before starting work. If I already gave an instruction in my message, confirm in one line how it fits the plan, and then proceed using the `/new_feature` or `/debug` workflow as appropriate.
