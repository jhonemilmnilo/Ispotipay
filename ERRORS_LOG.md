# ERRORS_LOG.md

> The project's memory of problems: every meaningful error, what caused it, how it was fixed, and how to avoid it next time. The goal is to **never fight the same bug twice** and to keep the code clean by fixing root causes instead of piling up workarounds.
> AI agents: read this before debugging. Check whether the problem was already solved. After fixing a non-trivial problem, record it here.
> Related files: `TASKS.md` (bug tracking), `DECISIONS.md` (choices that came from a fix), `AGENTS.md` (known gotchas).

<!--
TEMPLATE NOTE (delete after filling in):
- Delete the two EXAMPLE entries (ERR-EX1, ERR-EX2) once you have real ones.
- Never invent past errors. Only log problems that actually happened.
-->

---

## 1. Protocol for AI agents (MANDATORY)

### BEFORE debugging
1. **Search this file** for the error message, the file name, the library, or the symptom. If a matching entry exists, try that known solution first and tell me you are doing so.
2. Check **Section 2 (Prevention checklist)** and **Section 3 (Quick-lookup)**.
3. Get the facts: the **full error message**, stack trace, the command or action that triggered it, and versions involved. Do not guess from a partial message. If you lack this, ask me or run the command yourself and read the output.

### WHILE fixing (clean-code rules)
1. **Find the root cause before changing code.** Explain it to me in simple words (Taglish).
2. Fix the **cause, not the symptom**. These are NOT acceptable fixes:
   - Wrapping code in an empty `try/catch` to hide the error
   - Disabling lint, type checks, tests, CORS, SSL verification, or auth to make it go away
   - Adding `any`, `@ts-ignore`, `# type: ignore`, `eslint-disable`, or `// @ts-nocheck` without a real reason
   - Hard-coding values, adding random `setTimeout` delays, or retry loops to mask a race condition
   - Copying a fix from the internet without understanding it
   - Deleting or commenting out failing tests or code you do not understand
3. **Change one thing at a time**, then re-run to confirm. Do not stack several guesses.
4. Keep the fix **minimal and local**. Do not refactor unrelated code during a bugfix.
5. **Two-strike rule:** if the same approach fails twice, STOP. Summarize what you tried and learned, then propose a different approach or ask me for more information (logs, screenshots, versions). Do not try a third blind variation.
6. If you suspect an outdated or wrong API usage, check the **official docs or the installed package version** instead of relying on memory.
7. If a temporary workaround is truly unavoidable, mark it clearly in code with a comment (`// TEMP WORKAROUND: reason, remove when ...`), tell me, and add it to `TASKS.md` so it does not become permanent.

### AFTER fixing (verification)
1. Re-run the exact steps that reproduced the problem and **show me the result**.
2. Run the project's lint, type-check, build, and relevant tests. Confirm you introduced **no new warnings or errors**.
3. When it makes sense, **add a test** that would have caught the bug.
4. Check for the **same mistake elsewhere** in the codebase (search for similar patterns) and tell me what you found.
5. **Offer to log the problem** here ("Gusto mo bang i-log ko ito sa ERRORS_LOG.md?") if it meets the criteria below.

### What to log
Log when ANY of these is true:
- It took more than one attempt to fix.
- The cause was not obvious or the error message was misleading.
- It is likely to happen again (environment setup, a library quirk, a config mistake).
- It cost significant time or broke the app.
- It revealed a pattern to avoid.

Do NOT log: simple typos, one-line obvious mistakes, or problems already fully explained by an existing entry (instead, add "Recurred on [date]" to that entry).

### Rules
- Use real information only. Never invent errors, causes, or solutions.
- Never delete entries. If a solution later proves wrong, mark the entry `Superseded` and add the correct one.
- Never include secrets (keys, tokens, passwords) in logged error messages. Replace them with `[REDACTED]`.
- At the end of a debugging session, update `TASKS.md` (Bugs section) and `Session handoff` if anything remains unresolved.

---

## 2. Prevention checklist (keep the code clean)

> Grows over time. Add a line whenever an error teaches a lasting lesson.

**Before writing code**
- [ ] Checked the installed version of every library whose API I use
- [ ] Read the existing code in the area before changing it
- [ ] Task has clear acceptance criteria (`TASKS.md`)

**Before saying "done"**
- [ ] App runs with no errors in the terminal or browser console
- [ ] Build, lint, type-check, and tests pass (those that exist)
- [ ] Tested the happy path AND at least: empty input, invalid input, and failure case
- [ ] No leftover `console.log` / `print`, commented-out code, or unused imports
- [ ] No secrets in code; new env variables added to `.env.example`
- [ ] Docs updated if structure, env vars, or commands changed

**Lessons learned from this project**
- [FILL: add lessons here as they appear, e.g. "Restart the dev server after editing `.env`."]

---

## 3. Quick-lookup index

| ID | Date | Short symptom / error message | Area | Status |
|----|------|-------------------------------|------|--------|
| ERR-EX2 | [FILL: YYYY-MM-DD] | EXAMPLE: `Access to fetch ... blocked by CORS policy` on file upload | Storage / CORS | Resolved |
| ERR-EX1 | [FILL: YYYY-MM-DD] | EXAMPLE: `Module not found: Can't resolve '@/lib/db'` | Config / imports | Resolved |

**Status meanings:** `Open` (not solved) · `Resolved` (fixed and verified) · `Workaround` (temporary fix, root cause remains) · `Superseded` (a better solution was found later)

---

## 4. Error records (newest first)

### ERR-EX2: CORS error when uploading a file to storage
- **Date:** [FILL] | **Status:** Resolved (EXAMPLE, delete me) | **Area:** Storage / CORS | **Time lost:** ~1 hour
- **Symptom:** Browser console: `Access to fetch at '...' has been blocked by CORS policy`. Upload fails, but the same request works in a REST tool.
- **Trigger:** Uploading from `localhost:3000` to a private bucket via a presigned URL.
- **Root cause:** The bucket had no CORS rule allowing the app's origin and the `PUT` method. Browsers enforce CORS; server tools do not, which is why it worked elsewhere.
- **Failed attempts (do not repeat):**
  - Adding `mode: "no-cors"` to `fetch` (hides the response and breaks the upload).
  - Changing headers in the frontend only (the fix belongs on the bucket).
- **Fix:** Added a CORS rule on the bucket allowing origin `http://localhost:3000` (and the production domain), methods `PUT, GET`, and the needed headers.
- **Verification:** Upload succeeded from the browser; file appeared in the bucket; no console errors.
- **Prevention:** Configure bucket CORS at the same time as creating the bucket. Added to the prevention checklist.
- **Related:** `ARCHITECTURE.md` (Data flow A), `DECISIONS.md` D-EX2.

### ERR-EX1: Module not found for an import alias
- **Date:** [FILL] | **Status:** Resolved (EXAMPLE, delete me) | **Area:** Config / imports | **Time lost:** ~20 min
- **Symptom:** `Module not found: Can't resolve '@/lib/db'` right after creating a new file that uses the `@/` alias.
- **Trigger:** First import using the alias in a new folder.
- **Root cause:** The alias path was not defined in the project config (`paths` in `tsconfig.json`), so the build did not know what `@/` points to.
- **Failed attempts (do not repeat):**
  - Reinstalling `node_modules` (not the problem).
  - Switching to long relative paths (works but breaks the project convention).
- **Fix:** Added the correct `paths` entry and restarted the dev server.
- **Verification:** Build passed; import resolved in the editor and at runtime.
- **Prevention:** After changing config files, restart the dev server. Check the config before assuming a library problem.

<!-- Add new real entries ABOVE this line, newest first. -->

---

## 5. Template (copy for every new entry)

```
### ERR-XXX: Short, searchable title
- **Date:** YYYY-MM-DD | **Status:** Open | Resolved | Workaround | Superseded | **Area:** (e.g. auth, database, build, UI, env) | **Time lost:** estimate
- **Symptom:** The exact error message (key lines, secrets redacted) and what the user saw.
- **Trigger:** What action, command, or change caused it. Environment and versions if relevant.
- **Root cause:** The real reason, in plain words. (If still unknown, write "unknown" and list hypotheses.)
- **Failed attempts (do not repeat):**
  - What was tried and why it did not work
- **Fix:** What was changed, and where (files, config, command).
- **Verification:** How we confirmed it is truly fixed (commands, tests, manual steps).
- **Prevention:** How to avoid it in future. Add a line to Section 2 if the lesson is general.
- **Related:** links to TASKS.md items, DECISIONS.md entries, commits.
- **Recurred on:** (add dates if it happens again)
```

**ID numbering:** `ERR-001`, `ERR-002`, ... never reused or renumbered.

**Good entry:** exact error text, a real root cause, what failed, and how it was verified.
**Bad entry:** "Fixed the bug by changing some code." Say what, where, and why.
