# DECISIONS.md

> The memory of WHY. Every meaningful choice (stack, library, architecture, data model, approach) is recorded here with its reason, so we never have to re-argue it and so a new chat can understand the project without guessing.
> AI agents: read this before proposing changes to the stack, structure, or approach. Do not reverse a decision silently.
> What to build: `PROJECT_BRIEF.md`. How it is built: `ARCHITECTURE.md` and `AGENTS.md`. Progress: `TASKS.md`.

<!--
TEMPLATE NOTE (delete after filling in):
- Delete the two EXAMPLE entries (D-EX1, D-EX2) once you have real ones.
- For an EXISTING project with no log: scan the code and docs, draft the decisions that are clearly visible (stack, database, auth, storage, hosting). Mark reasons you cannot confirm as "(reason unknown, ask user)". Never invent reasons.
-->

---

## 1. Protocol for AI agents (MANDATORY)

### When to log a decision
Log an entry whenever any of these happen:
- Choosing or changing a **language, framework, database, auth method, hosting, or external service**.
- Adding a **new dependency** that matters (not tiny utilities).
- Choosing between **two or more reasonable approaches** (e.g. server-side vs client-side, REST vs GraphQL, one table vs two).
- Changing the **data model, folder structure, or API shape**.
- Deciding to **deliberately NOT do** something (a rejected option, a trade-off, a shortcut taken on purpose).
- Fixing a problem in a way that **sets a pattern** to follow later.

Do NOT log small things (variable names, minor styling, trivial edits).

### How to log
1. When a decision is made (or about to be made), **offer to record it**: "Gusto mo bang i-log ko ito sa DECISIONS.md?" Draft the entry using the template in Section 5.
2. Add it as `Proposed` while still discussing, and change to `Accepted` only after I approve.
3. Always include: the **context** (what problem), the **options considered**, the **choice**, the **reasons**, and the **consequences** (what gets easier and what gets harder).
4. Add a row to the **Index** (Section 2) and put the full entry in Section 3, **newest first**.
5. If the decision affects structure, stack, or schema, also update `ARCHITECTURE.md` or `AGENTS.md` and mention it in the entry.

### Rules
- **Never delete or rewrite history.** If a decision changes, set the old one to `Superseded by D-XXX` and write a new entry explaining what changed and why.
- Do not reverse or work around an `Accepted` decision. If you believe it is wrong, **tell me and propose a new decision**; wait for approval.
- Be honest about trade-offs. Do not write reasons that only make the choice look good; include the downsides.
- Use real information only. If the reason is unknown, write "reason not recorded" and ask me.
- At the **start of a session**, scan the Index so you respect what was already decided.

---

## 2. Index

| ID | Date | Decision | Status |
|----|------|----------|--------|
| D-EX2 | [FILL: YYYY-MM-DD] | EXAMPLE: Upload files directly to storage with presigned URLs | Accepted |
| D-EX1 | [FILL: YYYY-MM-DD] | EXAMPLE: Use Supabase instead of Firebase | Accepted |

**Status meanings:** `Proposed` (still discussing) · `Accepted` (follow this) · `Superseded by D-XXX` (replaced) · `Rejected` (considered and decided against) · `Deprecated` (no longer relevant)

---

## 3. Decision records (newest first)

### D-EX2: Upload files directly to storage with presigned URLs
- **Date:** [FILL]
- **Status:** Accepted (EXAMPLE, delete me)
- **Context:** Users upload images up to 5 MB. Sending files through our server would use extra bandwidth and hit serverless time limits.
- **Options considered:**
  1. Upload through our backend, then to storage.
  2. Browser uploads directly to storage using a short-lived presigned URL from our backend.
- **Decision:** Option 2.
- **Reasons:**
  - Files never pass through our server, so it is faster and avoids function limits.
  - The backend still checks login and file type before issuing the URL.
  - Secret keys stay on the server.
- **Consequences:**
  - Good: lighter server, simpler scaling.
  - Trade-off: needs CORS configured on the bucket; we must verify the upload afterward.
- **Affects:** `ARCHITECTURE.md` (Data flow A), upload route.
- **Revisit if:** we need server-side image processing before storing.

### D-EX1: Use Supabase instead of Firebase
- **Date:** [FILL]
- **Status:** Accepted (EXAMPLE, delete me)
- **Context:** The app needs a database, user accounts, and row-level permissions. I am a beginner and want a free tier and skills I can reuse.
- **Options considered:**
  1. Firebase (Firestore + Auth)
  2. Supabase (Postgres + Auth)
  3. SQLite + custom auth
- **Decision:** Supabase.
- **Reasons:**
  - Standard SQL/Postgres is a transferable skill and easy for AI tools to work with.
  - Built-in auth and Row Level Security.
  - Generous free tier for an MVP.
- **Consequences:**
  - Good: relational data fits the app (users have many orders).
  - Trade-off: must write RLS policies carefully; free projects may pause after inactivity.
- **Affects:** `AGENTS.md` (stack), `ARCHITECTURE.md` (database, auth).
- **Revisit if:** we outgrow the free tier or need real-time features at scale.

<!-- Add new real entries ABOVE this line, newest first. -->

---

## 4. Rejected ideas and "not now" (quick reference)

> Short list so the same ideas do not come back again and again. Details live in the full records above if there are any.

| Idea | Why not | Revisit when |
|------|---------|--------------|
| [FILL: e.g. Add a microservice backend] | [FILL: too complex for MVP] | [FILL: user count > X] |

---

## 5. Template (copy for every new decision)

```
### D-XXX: Short title of the decision
- **Date:** YYYY-MM-DD
- **Status:** Proposed | Accepted | Superseded by D-XXX | Rejected | Deprecated
- **Context:** What problem or situation forced a choice? (1-3 sentences)
- **Options considered:**
  1. Option A
  2. Option B
  3. Option C (including "do nothing" if relevant)
- **Decision:** The option chosen, in one sentence.
- **Reasons:**
  - Reason 1 (tie to PROJECT_BRIEF.md goals or constraints where possible)
  - Reason 2
- **Consequences:**
  - Good: what becomes easier
  - Trade-off: what becomes harder, risks, costs, limits
- **Affects:** files or docs to update (ARCHITECTURE.md, AGENTS.md, code areas)
- **Revisit if:** the condition that should trigger reconsidering this
- **Supersedes:** D-XXX (only if replacing an older decision)
```

**Numbering:** `D-001`, `D-002`, ... in order of creation. Never reuse or renumber an ID.

**Good entry:** states real alternatives, explains the reasons, and admits the downsides.
**Bad entry:** "Chose X because it is better." Say better in what way, compared to what.
