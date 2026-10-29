# [FILL: Project Name]

[FILL: One or two plain sentences: what this project is and who it is for.]

**Status:** [FILL: idea / in development / live] · **Live URL:** [FILL: link or "not deployed yet"] · **Last verified setup:** [FILL: YYYY-MM-DD]

<!--
TEMPLATE NOTE (delete after filling in):
This README is written for FUTURE YOU: someone who forgot everything and just wants the project running again.
Replace every [FILL: ...]. Delete sections that do not apply.

If you are an AI agent and this README is unfilled or outdated:
1. Fill it from the REAL project (package.json / requirements, config files, AGENTS.md, ARCHITECTURE.md, .env.example). Do not invent steps.
2. VERIFY every command before writing it. Run it, or mark it "(unverified)".
3. Never put real secrets or personal data in this file. Use variable names and placeholders only.
4. Show the draft and wait for approval before saving.
-->

---

## 1. What it does

- [FILL: Feature or capability 1]
- [FILL: Feature or capability 2]
- [FILL: Feature or capability 3]

Full goals and scope: see `PROJECT_BRIEF.md`.

## 2. Tech stack

[FILL: e.g. Next.js 15 · TypeScript · Tailwind CSS · Supabase (Postgres + Auth) · Cloudflare R2 (files) · Vercel (hosting)]

Exact versions and conventions: see `AGENTS.md`. Structure and data flow: see `ARCHITECTURE.md`.

## 3. Prerequisites

Install these first (check with the version command):

| Tool | Required version | Check with | Get it from |
|------|------------------|------------|-------------|
| [FILL: Node.js] | [FILL: 20+] | `node -v` | [FILL: nodejs.org] |
| [FILL: Package manager, e.g. npm / pnpm] | [FILL] | `[FILL]` | [FILL] |
| Git | any recent | `git --version` | git-scm.com |
| [FILL: other, e.g. Python 3.12 / Docker] | [FILL] | `[FILL]` | [FILL] |

**Accounts needed:** [FILL: e.g. Supabase, Cloudflare, Vercel, GitHub, or "none"]

## 4. Quick start (the 5-minute version)

```bash
# 1. Get the code
git clone [FILL: repo URL]
cd [FILL: project folder]

# 2. Install dependencies
[FILL: e.g. npm install]

# 3. Create your local environment file
cp .env.example .env
# then open .env and fill in the values (see Section 5)

# 4. Run the project
[FILL: e.g. npm run dev]
```

Open **[FILL: e.g. http://localhost:3000]** in your browser. If you see [FILL: what a working app looks like], it is working.

## 5. Environment variables

Real values go in `.env` (never committed). `.env.example` lists the names only.

| Variable | What it is | Where to get it |
|----------|------------|-----------------|
| `[FILL: e.g. SUPABASE_URL]` | [FILL: project URL] | [FILL: Supabase dashboard, Project Settings, API] |
| `[FILL: e.g. SUPABASE_ANON_KEY]` | [FILL: public key] | [FILL: same page] |
| `[FILL: e.g. R2_ACCOUNT_ID]` | [FILL: Cloudflare account ID] | [FILL: R2 overview page] |
| `[FILL: e.g. R2_ACCESS_KEY_ID]` | [FILL: R2 API token key] | [FILL: R2, Manage API tokens] |
| `[FILL: e.g. R2_SECRET_ACCESS_KEY]` | [FILL: shown only once when created] | [FILL: same place; if lost, create a new token] |
| `[FILL: e.g. R2_BUCKET_NAME]` | [FILL: bucket name] | [FILL: R2 bucket list] |

> Never share or commit `.env`. If a secret ever leaks, **rotate it immediately** (create a new one and delete the old one).

## 6. External services setup

Do these once per environment. Skip any service the project does not use.

**[FILL: e.g. Supabase]**
1. [FILL: Create a project at supabase.com]
2. [FILL: Copy the URL and keys into `.env`]
3. [FILL: Run the database setup: `command` or "apply files in `migrations/`"]
4. [FILL: Confirm Row Level Security is enabled]

**[FILL: e.g. Cloudflare R2]**
1. [FILL: Create a bucket (Standard storage class)]
2. [FILL: Create an API token with Object Read and Write, limited to that bucket]
3. [FILL: Add CORS rules for your app's origin(s) if the browser uploads directly]
4. [FILL: Put the credentials in `.env`]

## 7. Common commands

| Task | Command |
|------|---------|
| Install dependencies | `[FILL]` |
| Start dev server | `[FILL]` |
| Build for production | `[FILL]` |
| Run tests | `[FILL]` |
| Lint | `[FILL]` |
| Type-check | `[FILL]` |
| Format | `[FILL]` |
| Database migrate | `[FILL]` |

## 8. Project structure

```
[FILL: short tree, 2 levels, one-line purpose each; copy from AGENTS.md]
```

## 9. Deployment

- **Hosting:** [FILL: e.g. Vercel]
- **How it deploys:** [FILL: e.g. push to `main` auto-deploys / run `command`]
- **Production environment variables:** [FILL: set in the hosting dashboard; same names as `.env.example`]
- **After deploying, check:** [FILL: e.g. the home page loads, login works, an upload works]
- **Rollback:** [FILL: e.g. redeploy the previous version from the dashboard, or `git revert`]

## 10. Troubleshooting

| Problem | Likely cause | Fix |
|---------|--------------|-----|
| `command not found` for `[FILL: node / npm]` | Tool not installed or not in PATH | Install it (Section 3) and reopen the terminal |
| App starts but data or login fails | Missing or wrong value in `.env` | Compare `.env` with `.env.example`, then restart the dev server |
| Changed `.env` but nothing changed | Dev server still has the old values | Stop and restart the dev server |
| `Port [FILL: 3000] is already in use` | Another process is using it | Close the other process or use a different port |
| Install errors or weird dependency issues | Wrong tool version or a corrupted install | Check versions in Section 3; delete `[FILL: node_modules]` and reinstall |
| Browser upload blocked (CORS) | Bucket CORS missing your origin | Add the origin and methods to the bucket CORS rules |
| [FILL: project-specific problem] | [FILL] | [FILL] |

More solved problems: see `ERRORS_LOG.md`.

## 11. Resuming work after a long break

1. `git status`, then `git pull` to be up to date.
2. Run the install command again (dependencies may have changed).
3. Compare `.env` with `.env.example` for new variables.
4. Start the app and confirm it runs.
5. Read `TASKS.md` (Section 3: Session handoff) to see where you stopped.
6. With the AI agent, say: *"Basahin mo ang TASKS.md at ituloy natin."*

## 12. Project documents

| File | Purpose |
|------|---------|
| `PROJECT_BRIEF.md` | What the app is, for whom, features, scope |
| `ARCHITECTURE.md` | Structure, database, data flow, services |
| `AGENTS.md` | Stack, commands, conventions (rules for AI agents) |
| `TASKS.md` | Progress and next steps |
| `DECISIONS.md` | Why choices were made |
| `ERRORS_LOG.md` | Past problems and their solutions |

## 13. License and credits

[FILL: license, or "Private project, not for distribution"]

---

### Rules for AI agents maintaining this README

1. Keep it **accurate**. If a command, version, folder, or env variable changes, offer to update this file in the same task.
2. **Verify before documenting.** Do not write a command you have not run or confirmed.
3. Never include secrets, real keys, personal emails, or private URLs.
4. Keep it **beginner-friendly and short**. Link to other docs instead of duplicating them.
5. After setup-related changes (new env variable, new service, new command), also check `.env.example` and `AGENTS.md` for consistency.
