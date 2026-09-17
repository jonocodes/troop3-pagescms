# Pages CMS POC (`pagescms/`)

Proof-of-concept for one specific workflow: **the HTML lives in shared partials in
a GitHub repo, and someone logs into a web UI to edit those partials** — no manual
git, no markdown, no database of content.

Two parts:

| Path | What |
|------|------|
| `site/` | The design-6 site as an Eleventy build: 3 pages + shared HTML partials. Runs locally, builds to plain HTML. |
| `dev/`  | Local harness to self-host Pages CMS against Postgres. See `dev/README.md`. |

> **Status:** the `site/` half works and is verified (byte-identical rebuild, `npm run check`).
> The `dev/` half — **local self-hosting — is hard to run and was not completed end-to-end**.
> It needs Postgres, a GitHub App, and a GitHub repo, and pages-cms 2.1.8's setup
> helper fails GitHub's manifest validation three separate ways (see Findings).
> If you want this editing workflow, **use the hosted app at app.pagescms.org**;
> treat `dev/` as experimental.

---

## 1. The site (`site/`)

```
src/
  pages/index.html, join.html, calendar.html   # page bodies + front matter
  _includes/
    base.html      # <head>, page shell (head is the only per-page bit)
    header.html    # header + mobile menu + overlay
    footer.html    # footer (was copy-pasted 3x)
    scripts.html   # toggleMenu / toggleFaq / back-to-top
  styles.css, images/
.pages.yml         # Pages CMS config (sidebar of editable HTML files)
```

Run it:

```sh
cd poc/pagescms/site
npm install
npm run serve    # http://localhost:8084
npm run check    # build + assert shared header/footer, no unrendered tags
```

**The split, measured:** footer is 64 lines living in one file instead of three
copies (it was ~62 lines × 3); header/mobile-menu and scripts are each single-copy
too. `index.html` went from 629 lines to a 485-line body template.

Rendered output is byte-identical (whitespace-normalized) to `raw-html/` except
three intentional changes:

- the mobile menu now includes the "Join" link on every page (the raw index
  was missing it — copy-paste drift, fixed by having one partial)
- Home is linked as `index.html#home` on subpages (was bare `index.html`; same target)
- the footer's 1935/1936 evidence comment now appears on all pages (one copy in the partial)

## 2. Editing it in Pages CMS

`.pages.yml` at the site root turns into a sidebar:

```yaml
content:
  - name: templates
    label: Templates
    type: group
    items:
      - name: tpl-footer
        label: Footer
        type: file
        path: src/_includes/footer.html
        format: code
```

Each entry opens a **code editor over the actual `.html` file** — this is not
markdown or front-matter editing. Omitting `format` (and `fields`) gives Pages
CMS's raw-file editor instead of the code editor; both edit the whole file.

To run the CMS itself locally, see [`dev/README.md`](dev/README.md). The loop is:
editor saves → Pages CMS commits to the GitHub repo → your build/deploy runs
(the local Eleventy server picks changes up after a `git pull`).

---

## Findings

- **Pages CMS is a server app, not a drop-in static admin.** Sveltia/Decap ship
  an `/admin/` page inside your site; Pages CMS is a Next.js app + Postgres (or
  their hosted app at app.pagescms.org). That's why this POC has a `dev/` harness.
- **It edits GitHub repos only.** There is no local-folder mode (Sveltia has the
  File System Access API, Decap has a local proxy). So a "local" demo means
  self-hosting the app; the writes still go to GitHub.
- It boots locally without GitHub App credentials — the sign-in page renders
  with just a `Social provider github is missing clientId` warning. Creating the
  GitHub App (a browser flow, once) is the only interactive setup step.
- **Self-hosting is the hard part.** pages-cms 2.1.8's GitHub App setup helper
  fails GitHub's manifest validation three separate ways, each one blocking the
  whole registration:
  1. `hook_attributes.secret` is not a permitted key (`"secret" is not a permitted key`)
  2. the webhook URL is `localhost`, which GitHub now rejects (`Hook url is not
     supported because it isn't reachable over the public Internet`)
  3. `email_addresses` is not a permission resource name; GitHub's is `emails`
     (`Default permission records resource is not included in the list`)
  `dev/patches/pagescms-2.1.8-github-manifest-validation.patch` fixes all three
  and `setup.sh` applies it automatically, but the full flow (create app →
  install it → connect a repo → edit) was **not completed end-to-end** during
  this PoC. Between Postgres, the interactive GitHub App step, and a GitHub repo,
  local self-hosting is the wrong first move for this workflow.
- **A web code editor is still a code editor.** This solves "no manual git",
  not "no HTML". A non-technical editor can safely change words, links, and
  dates in a partial — and can also break the markup. If the requirement is
  "someone who doesn't know HTML", the only category that delivers that is
  visual editing (CloudCannon, TinaCMS), which needs content fields — the thing
  this POC deliberately avoids.

## Teardown

```sh
cd poc/pagescms/dev
docker-compose down -v    # stop + wipe the CMS database
rm -rf .pagescms          # remove the cloned Pages CMS app
```
