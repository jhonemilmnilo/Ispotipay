---
description: Fix an error properly. Checks ERRORS_LOG.md, reproduces, finds the root cause, makes a minimal clean fix, verifies, adds a regression test, and logs it. Stops after two failed attempts. Use as /debug.
---

# Debug Workflow

Goal: fix the **root cause** with a **clean, minimal change**, without hiding the problem. Reply in Taglish. Follow the debugging rules in `ERRORS_LOG.md`.

1. **Collect the facts.** Get the **full error message and stack trace** (ask me to paste it, or run the failing command and read the output yourself). Note: what I did before it happened, the command or page involved, and the versions (language, framework, key libraries). Do not guess from a partial message.

2. **Check the project memory.** Search `ERRORS_LOG.md` for the error text, file name, library, or symptom. Also check `TASKS.md` (Bugs) and `DECISIONS.md`. If a matching entry exists, tell me and try that known solution first.

3. **Make sure the state is safe.** Run `git status`. If there are uncommitted changes, recommend committing or stashing so we can go back. Do not run destructive commands.

4. **Reproduce the problem.** Find the exact steps or command that trigger it, and run them. If you cannot reproduce it, say so and ask for more information (logs, screenshots, environment). Do not "fix" something you cannot see.

5. **Isolate.** Narrow down where it happens: which file, function, request, or data. Read the relevant code and the error line by line. Check recent changes (`git diff`, `git log`) for what could have caused it. Check whether the issue is code, configuration, environment variables, versions, or data.

6. **Find the root cause.** Form one or two hypotheses and test them with evidence (logs, small experiments, reading docs or the installed library's source). If an API may be outdated or misremembered, check the **official docs or the installed version**. Then explain the cause to me in simple Taglish: what is happening, why, and why the error message shows what it shows.

7. **Propose the fix and WAIT if it is large.** Describe the smallest change that fixes the cause. Ask for my approval if it touches the database, authentication, dependencies, or many files.

8. **Apply the fix, one change at a time.** Keep it minimal and local. **Not acceptable:**
   - empty `try/catch` or swallowing errors
   - disabling lint, type checks, tests, CORS, SSL verification, authentication, or security rules
   - `any`, `@ts-ignore`, `# type: ignore`, `eslint-disable` without a real reason
   - random delays, retries, or hard-coded values that hide a race condition or bad data
   - deleting or skipping failing tests
   - refactoring unrelated code

   If a temporary workaround is truly unavoidable, mark it `TEMP WORKAROUND: reason, remove when ...`, tell me, and add it to `TASKS.md`.

9. **Two-strike rule.** If the same approach fails twice, **stop**. Summarize what you tried, what you learned, and what is still unknown. Then propose a different approach or ask me for specific information. Do not try a third blind variation.

10. **Verify the fix.** Re-run the exact steps that reproduced the problem and show me the result. Then run lint, type-check, tests, and build. Confirm there are **no new errors or warnings**.

11. **Add a regression test** that fails without the fix and passes with it. If the project has no test setup, write clear manual steps instead.

12. **Look for the same mistake elsewhere.** Search the codebase for similar patterns and tell me what you find. Do not change them without telling me.

13. **Log it.** If the problem needed more than one attempt, had a misleading message, could happen again, or cost real time, offer to add an entry to `ERRORS_LOG.md` (symptom, trigger, root cause, failed attempts, fix, verification, prevention). Redact secrets. If it matches an existing entry, add "Recurred on <date>" instead. Update the Prevention checklist if the lesson is general. Update `TASKS.md` (Bugs and Session handoff).

14. **Report** in this exact format:
    - **Problema:** what was wrong (symptom)
    - **Dahilan (root cause):** why it happened, in simple words
    - **Ayos:** what was changed and where
    - **Verification:** reproduction result, lint / type-check / tests / build
    - **Pag-iwas:** how to prevent it next time
    - **Napansin / Risks:** anything uncertain or still open

15. **Suggest a commit message** (e.g. `Fix ...`). Do not commit unless I ask.
