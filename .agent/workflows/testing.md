# TESTING RULES (always apply)

Place at `.agent/rules/testing.md` and set it to be always active. These rules apply to **every stack and every project**. Goal: catch errors early, prove that things work, and never fool ourselves with "it should work."

## 0. Golden rules

1. **Never say "done", "fixed", or "works" without evidence.** Run it and show me the result. If you could not run something, say "hindi ko pa na-test" and explain why.
2. **Test after every small change**, not after ten changes.
3. **Never weaken a test to make it pass.** Do not delete, skip (`skip`, `xit`, `@pytest.mark.skip`), comment out, or loosen assertions of a failing test without telling me why and getting approval. A failing test is information. Find out whether the code or the test is wrong.
4. **Report honestly**: passed, failed, not run, with the exact commands used.

## 1. First, find out how this project tests

1. Read `AGENTS.md` for the test commands. Do not guess them.
2. Detect the setup from config files (`package.json` scripts, `pytest.ini`, `vitest.config`, `jest.config`, `go.mod`, etc.) and existing test folders and naming.
3. **Use the framework already in the project.** Do not add a second test framework.
4. If the project has **no tests**: do not silently add a framework. Suggest the standard choice for the stack, explain it simply, and ask for approval. Until then, use manual verification (Section 6) and run build, lint, and type-check.

## 2. When to test

| Situation | What to do |
|-----------|-----------|
| Any code change | Run the relevant existing tests, plus lint and type-check |
| New feature | Add tests for the new logic and its edge cases, then run all related tests |
| Bug fix | **Reproduce first** (write a failing test or exact manual steps), fix, confirm it passes, keep the test as a regression guard |
| Refactor | Make sure tests pass **before and after**; behavior must not change |
| Dependency or config change | Run the full test suite and a build |
| Before saying a task is done | Run everything that exists: tests, lint, type-check, build |
| Before a commit or deploy | Run the `/pre_commit_check` workflow |

## 3. What to test (priorities)

Test the things that would hurt most if broken:

1. **Security-critical code:** authentication, authorization (a user cannot access another user's data), input validation, file upload checks, rate limits.
2. **Business logic:** calculations, rules, state changes, anything involving money, permissions, or data deletion.
3. **Data handling:** parsing, transformation, database queries and migrations.
4. **API endpoints:** valid request, invalid request, unauthenticated, unauthorized, not found, server error.
5. **UI behavior:** key user flows, form validation, loading, empty, and error states.
6. **Regressions:** every bug that was fixed.

Do not waste effort testing framework internals, trivial getters, or third-party libraries.

## 4. What to cover for each piece of logic

- **Happy path:** normal valid input.
- **Edge cases:** empty, null/undefined, zero, negative, very large, very long, boundary values, duplicates, special characters, unicode.
- **Invalid input:** wrong type, wrong format, missing required fields, malicious strings (`' OR 1=1`, `<script>`).
- **Failure paths:** network error, timeout, database error, service unavailable, expired or invalid token. Confirm errors are handled and **do not leak internal details**.
- **Permissions:** logged out, wrong role, wrong owner.
- **Concurrency or repeats** (when relevant): double submit, retry, race conditions.

## 5. How to write good tests

- **Structure:** Arrange (setup), Act (do one thing), Assert (check the result). One behavior per test.
- **Names describe behavior:** `rejects_signup_when_email_is_already_registered`, not `test1`.
- Tests must be **independent and repeatable**: no reliance on order, shared state, current date/time, randomness, or real external services. Control these with fixed values or fakes.
- **No real network calls, no production database, no real secrets or real personal data** in tests. Use test databases, fixtures, and fake values.
- **Mock only at the boundaries** (external APIs, email, payments, storage). Do not mock the code under test. Over-mocking makes tests pass while the app is broken.
- Assert **meaningful results**, not just "does not throw." Check actual values, status codes, and side effects.
- Keep tests **fast** and readable. Prefer a few clear tests over many fragile ones.
- Put tests where the project already puts them and follow its naming pattern.
- Clean up after tests (created data, files, timers).
- **Flaky tests** (sometimes pass, sometimes fail) must be fixed or reported to me; never just re-run until green.

## 6. Manual testing (when no automated test exists or for UI)

When tools allow, run the app and actually try it. Describe what you did and saw.

- Test the happy path, then at least: **empty input, invalid input, and one failure case.**
- For UI: check the browser console for errors, check loading, empty, and error states, and check a narrow mobile width.
- For APIs: try with a REST client or `curl`, including a request without login and one as the wrong user.
- Give me a short **"Paano i-test"** list of steps so I can verify it myself.

## 7. Running checks and reporting

Run what exists, in this order: **format/lint, type-check, unit/integration tests, build.** Fix failures one at a time (see the debugging protocol in `ERRORS_LOG.md`).

Report in this format:

```
Verification:
- Lint:        PASS / FAIL / not available
- Type-check:  PASS / FAIL / not available
- Tests:       PASS (X passed, Y failed, Z skipped) / not available
- Build:       PASS / FAIL / not available
- Manual:      what I tried and what I saw
- Not tested:  what remains untested and why
```

Never report "all green" when something was skipped or not run. Treat new warnings as failures to review.

## 8. Test levels (use the right one)

- **Unit tests:** small pieces of logic in isolation. Most numerous, fastest.
- **Integration tests:** several parts together (API route plus database, service plus storage). For the main flows.
- **End-to-end (E2E) tests:** a real user flow through the whole app. Few, for critical paths only (sign up, login, checkout, upload).
- Do not chase 100% coverage. Aim for **meaningful coverage of important and risky code**. Coverage numbers do not prove quality.

## 9. Before marking any task done

- [ ] New and changed logic has tests (or documented manual steps if no test setup exists)
- [ ] Bug fixes include a regression test
- [ ] Edge, invalid, and failure cases were covered
- [ ] No skipped, deleted, or weakened tests
- [ ] Lint, type-check, tests, and build were run, with results shown honestly
- [ ] No real secrets or personal data in test files or fixtures
- [ ] I received clear steps to verify it myself
