---
description: Final checklist before committing or deploying. Reviews the diff, scans for secrets and debug leftovers, runs lint, type-check, tests, and build, checks docs, and suggests a commit message. Never commits on its own. Use as /pre_commit_check.
---

# Pre-Commit Check Workflow

Goal: make sure what we are about to commit is clean, safe, and working. Reply in Taglish. **Do not commit or push** unless I explicitly ask. Report every result honestly.

1. **See what changed.** Run `git status` and `git diff` (and `git diff --staged`). List the changed, added, and deleted files. Flag anything unexpected: files unrelated to the task, large files, generated files, build output, or `node_modules`/virtual environments.

2. **Review the diff like a reviewer.** Read the changes and check for:
   - unrelated edits, accidental renames, or noisy reformatting
   - leftover debug code: `console.log`, `print`, `debugger`, test-only shortcuts
   - commented-out code, unused imports or variables, dead code
   - `TODO` without a task ID, and `TEMP WORKAROUND` that is not listed in `TASKS.md`
   - lint or type suppressions (`eslint-disable`, `@ts-ignore`, `# noqa`, `# type: ignore`) without a reason
   - hard-coded URLs, IDs, credentials, or "magic" values

3. **Secrets scan (critical).** Search the diff and new files for secrets: API keys, tokens, passwords, private keys, connection strings, webhook secrets, `.env` content. Also confirm:
   - `.env` and other secret files are **not** staged and are in `.gitignore`
   - `.env.example` contains **names only**, and includes any new variable
   - no secret appears in logs, test fixtures, docs, or comments

   If anything is found: **stop**, tell me, and explain how to remove it and rotate the secret. Removing it from the latest commit is not enough if it was committed earlier.

4. **Run the checks** that exist (use the commands in `AGENTS.md`), in this order: format/lint, type-check, tests, build. Show the real results. Fix failures one at a time. Do not skip, delete, or weaken tests to get a pass.

5. **Run the app and smoke-test** the changed area when tools allow: it starts, the main flow works, and there are no errors in the terminal or browser console.

6. **Security quick review** of the changed code (see `security.md` and `security-infra.md`): inputs validated on the server, authentication and authorization on every new or changed endpoint, no raw user HTML, upload restrictions, generic error messages, no new risky permissions, new dependencies verified and necessary.

7. **Dependencies.** If `package.json` / `requirements.txt` / the lockfile changed: confirm each new package was approved, is spelled correctly and real, and that the lockfile is included. Run the audit command if available and report findings.

8. **Documentation and project memory.** Check that these are updated if affected:
   - `README.md` and `.env.example` (setup, commands, env variables)
   - `ARCHITECTURE.md` and `AGENTS.md` (structure, schema, routes, services)
   - `DECISIONS.md` (meaningful choices) and `ERRORS_LOG.md` (problems fixed)
   - `TASKS.md` (tasks marked correctly, Done log, Session handoff)

9. **Give me a verdict.** Use this format:

    ```
    Pre-commit result: READY / NOT READY
    - Diff review:   OK / issues found
    - Secrets scan:  OK / FOUND
    - Lint:          PASS / FAIL / not available
    - Type-check:    PASS / FAIL / not available
    - Tests:         PASS (X passed, Y failed, Z skipped) / not available
    - Build:         PASS / FAIL / not available
    - Smoke test:    what was tried and seen
    - Security:      OK / concerns (list)
    - Docs updated:  yes / needs update (list)
    - Not checked:   anything skipped and why
    ```

   Say **NOT READY** if any check failed, any secret was found, or any step was not run without a good reason.

10. **Suggest the commit.** If READY, suggest one short, imperative English commit message (follow the project's style, e.g. Conventional Commits) and the exact commands to run, and suggest splitting into separate commits if the changes mix unrelated work. Wait for me to say go before running `git commit`. Never run `git push --force`.
