# Local Pages CMS (self-hosted) — experimental, known-hard

> **Status: abandoned mid-setup; do not expect a smooth run.** The app itself
> boots, but registering the GitHub App required patching three separate
> manifest-validation bugs in pages-cms 2.1.8's helper, and the full flow
> (create app → install → connect a repo → edit) was never completed end-to-end
> here. If you want this editing workflow, use the hosted app at
> **app.pagescms.org** instead — same UI, no Postgres, no GitHub App to create.
> This folder stays as a record of what local self-hosting actually costs.

Runs the real Pages CMS at **http://localhost:3000** against Postgres, so the
editing UI can be tried locally. Note: Pages CMS only ever edits **GitHub**
repos — there is no local-folder mode. See [`../README.md`](../README.md) for how
this fits the workflow.

Pinned to Pages CMS **2.1.8** in `setup.sh`.

## Requirements

- Docker **or** Podman with compose (Postgres runs in a container)
- Node 20+ and git on the host (the Pages CMS app runs on the host, not in a container)

## Bring it up

```sh
cd poc/pagescms/dev

# 1. Postgres 16 (host port 55432)
docker-compose up -d

# 2. Clone pages-cms 2.1.8 into .pagescms/, npm install, write .env.local, migrate
./setup.sh

# 3. Create the GitHub App for this local instance — browser flow, once.
#    If no browser opens, visit the URL it prints (default http://127.0.0.1:8787/start)
#    and click "Create GitHub App". It writes GITHUB_APP_* into .env.local, then exits.
cd .pagescms
npm run setup:github-app -- --base-url http://localhost:3000 --env .env.local

# 4. Start it — must be run from .pagescms/, not from dev/
npm run dev        # http://localhost:3000
```

Everything from here on runs **inside `.pagescms/`**. Running npm commands from
`dev/` itself fails (there is no `package.json` there).

`.pagescms/` is in the repo's `.gitignore`; nothing here is committed.

## Connect the demo site

Pages CMS reads `.pages.yml` from the **root** of the repo it is connected to, so
push `site/` as its own GitHub repo:

```sh
cd ../../site
git init && git add -A && git commit -m "Pack 3 site (Pages CMS demo)"
gh repo create pack3-pagescms-demo --private --source=. --push
```

Then in the app: install the GitHub App on that repo, pick it, and the sidebar
shows **Pages** (index/join/calendar) and **Templates** (base/header/footer/scripts).
Open `Footer`, change some text, save → Pages CMS commits it to GitHub.

To see the change locally, `git pull` in `site/` while `npm run serve` is running
(Eleventy rebuilds on change).

## Why these details matter

- **Host port 55432.** This machine already had 5432, 5433, 5434 and 5440 in use.
- **`openssl` is not on PATH (NixOS)**, so `setup.sh` generates the auth secrets
  with `node -e "crypto.randomBytes(...)"` instead.
- **The Better Auth warning** (`Social provider github is missing clientId or
  clientSecret`) is expected before step 3 — the app still boots and serves its
  sign-in page.
- **Manifest workarounds are required** — pages-cms 2.1.8's helper trips three
  GitHub validation errors, each of which rejects the entire app registration:
  1. `hook_attributes.secret` → `"secret" is not a permitted key` (GitHub only
     permits `url` and `active`; it generates the webhook secret server-side and
     returns it from the conversion call, so the patch uses that instead)
  2. `hook_attributes.url` pointing at `localhost` → `Hook url is not supported
     because it isn't reachable over the public Internet` (patch omits the hook
     for localhost)
  3. permission `email_addresses` → `Default permission records resource is not
     included in the list` (GitHub's resource name is `emails`)
  `setup.sh` resets the helper file to the pinned tag and applies
  `patches/pagescms-2.1.8-github-manifest-validation.patch`. Even with the patch,
  the app-creation step was never completed end-to-end in this PoC.
- **`setup.sh` is idempotent** — re-running it reuses the clone and `.env.local`,
  re-applies the patch and migrations.
- If config/cache state goes stale in the app: `npm run db:clear-cache`.
  GitHub is always the source of truth; the database only holds app state.

## What this is NOT

A production setup — it's a local harness (HTTP, local Postgres, one user).
For real use, either self-host properly (see Pages CMS's Vercel/self-host guides)
or use their hosted app at app.pagescms.org.

## Stop / reset

```sh
docker-compose down        # stop, keep the database
docker-compose down -v     # stop and wipe the database
rm -rf .pagescms           # remove the app clone entirely
```
