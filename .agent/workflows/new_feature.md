---
description: Build one feature safely, in small verified steps. Reads project docs, plans, waits for approval, implements, tests, reviews security, updates docs, and reports. Use as /new_feature.
---

# New Feature Workflow

Follow every step in order. Do not skip steps. Reply in Taglish. Do not run commands marked "ask first" without my approval.

1. **Load context.** Read `TASKS.md` (Current focus and Session handoff), `AGENTS.md`, `PROJECT_BRIEF.md`, `ARCHITECTURE.md`, `DECISIONS.md`, and `ERRORS_LOG.md` if they exist. Note the stack, commands, conventions, and past decisions or errors that relate to this feature.

2. **Identify the task.**
   - Use the feature or task I named. If I did not name one, take the first unblocked `[ ]` task in priority order from `TASKS.md` and confirm it with me.
   - If the feature is not in `PROJECT_BRIEF.md`, check it against the **Out of scope** list. If it conflicts, tell me and ask whether to update the brief first.
   - If it is too big (size L) or vague, **split it into small tasks** with acceptance criteria and show me the split before continuing.

3. **Check the starting state.**
   - Run `git status`. If there are uncommitted changes, tell me and recommend committing or stashing first.
   - Confirm the app currently builds and runs. If it is already broken, tell me before adding anything new.
   - Suggest a new branch name (e.g. `feature/<short-name>`) and ask before creating it.

4. **Clarify requirements.** Restate the feature in 2 to 3 sentences and list the **acceptance criteria** (what must be true for it to be done). If anything important is unclear, ask me in **one short batch of questions**. For small gaps, state your assumption and continue.

5. **Make a plan and WAIT for my approval.** Show:
   - Files to create or change, in order
   - Any database/schema change (needs my approval and a migration)
   - New dependencies (name, purpose, and verification that the package is real; needs my approval)
   - New env variables or external service changes
   - Security impact: authentication, authorization, input validation, file handling, secrets
   - Tests to add
   - Risks and what could break

   **Do not write code until I approve the plan.**

6. **Update `TASKS.md`.** Set the task to `[~]`, fill in Current focus (goal, branch, steps, how to test).

7. **Implement in small steps.**
   - Follow `.agent/rules/code-style.md`, `security.md`, `security-infra.md`, and `testing.md`.
   - Match existing patterns in the project; reuse existing components and helpers.
   - After each meaningful step, run the app or relevant tests to make sure nothing broke.
   - If extra work appears (bugs, ideas, refactors), **do not do it now**. Add it to Backlog or Bugs in `TASKS.md` and tell me.
   - If the plan stops working, **stop and explain** before changing direction.

8. **Write tests** for the new logic and its edge cases (empty, invalid, failure, wrong permission). If the project has no test setup, give me clear manual test steps instead and suggest a test setup.

9. **Verify.** Run lint, type-check, tests, and build (whatever exists). Fix failures one at a time. Try the feature manually when tools allow. Show me the real results; never claim a pass you did not see.

10. **Quick security check.** Confirm: no secrets in code, all inputs validated on the server, authentication and authorization checked on every new endpoint, no raw user HTML, uploads restricted, errors generic. List anything not checked.

11. **Update documentation.** If affected, update `.env.example`, `README.md`, `ARCHITECTURE.md`, `AGENTS.md`. If a meaningful choice was made, offer to log it in `DECISIONS.md`.

12. **Close out `TASKS.md`.** Mark `[x]` only if every acceptance criterion is met and verified. Add a line to the Done log, clear Current focus, and update Session handoff.

13. **Report** in this exact format:
    - **Ginawa:** what changed (files)
    - **Paano i-test:** steps for me to check it myself
    - **Verification:** lint / type-check / tests / build / manual results
    - **Napansin / Risks:** anything uncertain, skipped, or not tested
    - **Susunod:** the next suggested task

14. **Suggest a commit message** (short, imperative, English). Do not commit or push unless I ask.
