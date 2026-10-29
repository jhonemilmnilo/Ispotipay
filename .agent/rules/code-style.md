# CODE STYLE RULES (always apply)

Place at `.agent/rules/code-style.md` and set it to be always active. These defaults apply to **every stack and every project**. Goal: clean, readable, consistent code that a beginner can understand and maintain.

## 0. Golden rules

1. **The project comes first.** Follow the existing conventions, formatter, and linter config of the project, and what `AGENTS.md` says. These defaults are used only where the project says nothing.
2. **Readable beats clever.** Write the simplest code that works and is easy to understand.
3. **Consistency beats preference.** Match the surrounding code, even if you would write it differently.
4. **Smallest change that solves the task.** No drive-by refactors, renames, or reformatting of unrelated code.
5. If a rule here conflicts with a security rule, **the security rule wins**.

## 1. Naming

**General**
- Names must reveal **intent**: `getUserById`, `isEmailValid`, `totalPriceCents`. Avoid `data`, `temp`, `x`, `thing`, `handleStuff`.
- Use full words. Skip cryptic abbreviations (common ones are fine: `id`, `url`, `db`, `api`, `ui`).
- **Functions are verbs** (`createOrder`, `sendEmail`). **Variables, classes, and types are nouns** (`order`, `EmailService`).
- **Booleans** start with `is`, `has`, `can`, or `should` (`isLoading`, `hasAccess`). Avoid negatives like `isNotValid`.
- **Collections are plural** (`users`), single items singular (`user`).
- Put **units** in names when ambiguous: `timeoutMs`, `maxSizeBytes`, `priceCents`.
- True constants use `UPPER_SNAKE_CASE`. No magic numbers or strings; give them a named constant.
- Code, names, and comments are in **English**.
- If a name no longer matches what the code does, **rename it**.

**Default casing (use the project's own style if different)**

| Language / area | Variables, functions | Classes, types, components | Files | Constants |
|-----------------|----------------------|----------------------------|-------|-----------|
| JavaScript / TypeScript | `camelCase` | `PascalCase` | `kebab-case` (components may be `PascalCase`) | `UPPER_SNAKE_CASE` |
| Python | `snake_case` | `PascalCase` | `snake_case.py` | `UPPER_SNAKE_CASE` |
| Java / Kotlin | `camelCase` | `PascalCase` | `PascalCase` | `UPPER_SNAKE_CASE` |
| C# | `camelCase` (methods `PascalCase`) | `PascalCase` | `PascalCase` | `PascalCase` |
| Go | `camelCase` (exported `PascalCase`) | `PascalCase` | `lowercase` | per convention |
| Rust | `snake_case` | `PascalCase` | `snake_case` | `UPPER_SNAKE_CASE` |
| Database | `snake_case` tables and columns | n/a | n/a | n/a |
| CSS classes | `kebab-case` (or the project's method) | n/a | n/a | n/a |
| Environment variables | `UPPER_SNAKE_CASE` | n/a | n/a | n/a |

## 2. Structure and organization

- **One responsibility** per file, function, and module. If you need "and" to describe it, split it.
- **Size guide:** functions around 30 lines or fewer (consider splitting past ~50); files around 300 lines or fewer. Tell me before splitting a big file.
- **Parameters:** 4 or fewer; otherwise pass an object.
- **Nesting:** 3 levels or fewer. Use **early returns / guard clauses** instead of deep `if` pyramids.
- **Follow `ARCHITECTURE.md`:** respect layers and where each kind of code belongs. Do not create new top-level folders or new patterns without asking.
- Organize the way the project already does (by feature or by type). Do not mix both.
- **Imports:** group as built-in, external packages, internal modules, relative. Remove unused imports. Avoid circular dependencies. Use the project's path aliases.
- No giant `utils` dumping ground. Name helper files by purpose (`date-format`, `price-calc`).
- **Avoid duplication, but do not over-abstract.** Extract shared code on the third repetition (rule of three). Do not build for needs that do not exist yet.
- Keep **pure logic separate from side effects** (I/O, network, database, UI) so it is easy to test.
- **Delete dead code.** Do not comment it out; git remembers it.

## 3. Functions, types, and errors

- Use **types** wherever the language supports them. No `any` (TypeScript), untyped public functions (Python), or unchecked casts without a reason and a comment.
- Handle **null/undefined/empty** cases explicitly; do not assume data exists.
- Prefer **immutability**: do not mutate function arguments or shared state. Avoid global mutable state.
- Return **consistent shapes** from a function; avoid returning different types in different branches.
- **Async:** use `async/await` consistently; always handle rejections; no floating (unawaited) promises.
- **Errors:** never leave an empty `catch` or swallow errors silently. Either handle the error meaningfully, add context and rethrow, or report it. Use clear, specific error messages. Do not use exceptions for normal control flow.
- Validate at boundaries (API, forms, files), then trust typed data inside.

## 4. Comments and documentation

- **Code explains WHAT; comments explain WHY** (non-obvious decisions, constraints, workarounds, links to issues or docs).
- Do not comment the obvious. Do not leave **commented-out code**. Update or delete comments when code changes; stale comments are bugs.
- Write **docstrings / JSDoc** for exported functions, public APIs, and complex logic: purpose, parameters, return value, errors thrown.
- Explain unusual **regexes, formulas, and algorithms** in one or two lines.
- **TODO format:** `TODO(T-012): what and why`. No TODO without a task ID, and tell me when you add one.
- Temporary workarounds use `TEMP WORKAROUND: reason, remove when ...` and must be listed in `TASKS.md`.
- Because I am a beginner: when you introduce a new pattern or concept, explain it in 1 to 3 simple sentences in the chat (Taglish). Keep the code itself uncluttered.

## 5. Formatting and tooling

- Use the project's **formatter and linter** (Prettier, ESLint, Black, Ruff, gofmt, etc.) and run them after your changes. **Do not change their config** without my approval.
- If the project has none, suggest the standard one for the stack and ask before adding it.
- Do not reformat files you are not otherwise changing (it creates noisy diffs).
- Match existing indentation, quote style, semicolons, line length, and trailing newline.
- Fix warnings you introduce. Do not silence them with `eslint-disable`, `@ts-ignore`, `# noqa`, or `# type: ignore` unless there is a real reason, stated in a comment and mentioned to me.

## 6. Frontend / UI (when applicable)

- **Small, single-purpose components** with typed props. **Reuse existing components** before creating new ones.
- Keep display separate from data fetching and business logic, the way the project already does.
- Always handle **loading, empty, and error states**.
- **Accessibility:** semantic HTML, labels on inputs, `alt` text, keyboard support, adequate contrast.
- **Responsive**, mobile-first.
- Styling: use the project's approach (Tailwind, CSS modules, design tokens). No inline styles or hard-coded colors and sizes when tokens exist.
- No leftover `console.log` or debug UI.

## 7. Backend and data (when applicable)

- **Thin routes/controllers**, logic in services, data access in one place.
- Consistent API response and error format (see `ARCHITECTURE.md`).
- Avoid N+1 queries (queries inside loops). Ask before adding indexes or changing schema.
- Read environment variables in **one config module**, not scattered across the code.
- Logging: use levels, add useful context, never log secrets or personal data.

## 8. Change discipline

- **Refactor only when asked or required for the task**, and keep it separate from feature work (separate task or commit).
- Do not rename or move files unnecessarily. Preserve behavior when refactoring and test before and after.
- Do not add a dependency for something trivial or already in the standard library or framework.
- Use syntax and APIs that match the **installed versions**.
- Leave the files you touch a little cleaner, within the scope of the task.

## 9. Self-review before saying "done"

- [ ] Names are clear; no magic numbers or strings
- [ ] Functions and files are focused and not too long; no deep nesting
- [ ] No duplicated logic, dead code, commented-out code, unused imports, or debug prints
- [ ] Errors handled properly; no empty `catch`; no `any` or lint suppressions without reason
- [ ] Types added; edge cases (empty, null, invalid) handled
- [ ] Comments explain "why"; public functions documented; TODOs have task IDs
- [ ] Formatter and linter pass with no new warnings
- [ ] Follows `ARCHITECTURE.md` and `AGENTS.md`; no unrelated changes in the diff
