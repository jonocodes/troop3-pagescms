# Pages CMS POC (`pagescms/`)

Proof-of-concept for one specific workflow: **the HTML lives in shared partials in
a GitHub repo, and someone logs into a web UI to edit those partials** — no manual
git, no markdown, no database of content.

The Eleventy site lives at the **repo root** so that Pages CMS (which reads
`.pages.yml` from the root of the repo it edits) can be pointed straight at this
repo. The experimental self-hosting harness lives in `dev/`.

| Path | What |
|------|------|
| root (`src/`, `.pages.yml`, `eleventy.config.js`, …) | The design-6 site as an Eleventy build: 3 pages + shared HTML partials. Runs locally, builds to plain HTML. |
| `dev/`  | Local harness to self-host Pages CMS against Postgres. See `dev/README.md`. |

**Live site:** deployed to GitHub Pages at
<https://jonocodes.github.io/troop3-pagescms/> by
`.github/workflows/deploy-site.yml` on every push to `main`.

> **Status:** the site half works and is verified (byte-identical rebuild, `npm run check`).
> The `dev/` half — **local self-hosting — is hard to run and was not completed end-to-end**.
> It needs Postgres, a GitHub App, and a GitHub repo, and pages-cms 2.1.8's setup
> helper fails GitHub's manifest validation three separate ways (see Findings).
> If you want this editing workflow, **use the hosted app at app.pagescms.org**
> (or connect it to this repo directly); treat `dev/` as experimental.

---

## 1. The site

```
src/
  pages/index.html, join.html, calendar.html   # page bodies + front matter
  _includes/
    base.html      # <head>, page shell (head is the only per-page bit)
    header.html    # header + mobile menu + overlay
    footer.html    # footer (was copy-pasted 3x)
    scripts.html   # toggleMenu / toggleFaq / back-to-top
    blocks/        # one template per content block type
      welcome.html # Home welcome section, rendered from a `sections` block
      icons/*.svg  # icon set the welcome block's `values[].icon` picks from
  styles.css, images/
.pages.yml         # Pages CMS config: Home = block editor, rest = code editor
eleventy.config.js, package.json, check.js
```

Run it (from the repo root):

```sh
npm install
npm run serve    # http://localhost:8084
npm run check    # build + assert shared header/footer, no unrendered tags
```

**The split, measured:** footer is 64 lines living in one file instead of three
copies (it was ~62 lines × 3); header/mobile-menu and scripts are each single-copy
too. `index.html`'s body is a 440-line template; the welcome copy moved from
inline HTML into front-matter content blocks (rendered by `blocks/welcome.html`).

Rendered output is byte-identical (whitespace-normalized) to `raw-html/` except
three intentional changes:

- the mobile menu now includes the "Join" link on every page (the raw index
  was missing it — copy-paste drift, fixed by having one partial)
- Home is linked as `index.html#home` on subpages (was bare `index.html`; same target)
- the footer's 1935/1936 evidence comment now appears on all pages (one copy in the partial)

## 2. Editing it in Pages CMS

`.pages.yml` at the repo root turns into a sidebar:

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

### Content blocks (the Home page)

The **Home** entry is the exception: it uses structured fields, not a code
editor. The editable copy lives in `index.html` front matter as a list of typed
`sections` blocks, and Pages CMS renders a page-builder-style block editor
(dropdown to pick a block type, then plain fields). The rest of `index.html` —
layout keys and the HTML body — is still shown as a code field so nothing is
unreachable.

How it fits together:

- **Data:** `index.html` front matter has `sections:` (one `welcome` block).
- **Schema:** `.pages.yml` models it with `type: block, list: true, blockKey: type`
  and per-block fields (`string`, `rich-text` with `format: markdown`, `text`,
  and a nested `values` object list using a `select` for the icon).
- **Render:** the page loops the blocks and includes one partial per type:
  `{% for section in sections %}{% include "blocks/" + section.type + ".html" %}{% endfor %}`.
  `src/_includes/blocks/welcome.html` is that template; `values[].icon` includes
  an SVG from `blocks/icons/`.
- **Markdown:** `eleventy.config.js` registers a `markdownify` filter (markdown-it)
  because Eleventy v3 dropped the built-in one. `intro` is rendered with
  `{{ section.intro | markdownify | safe }}`.
- **Safety:** `settings.content.merge: true` in `.pages.yml` means a save merges
  the submitted fields into the file, so keys and the HTML body outside the
  schema survive. Without it, a structured save rewrites the file from the
  schema only — i.e. it would wipe the template.

Add a new `blocks/<name>` definition in `.pages.yml` plus a matching
`src/_includes/blocks/<name>.html` partial to grow the page-builder.

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
  this POC originally avoided.
- **Content fields are available in Pages CMS itself** (`type: block`,
  `rich-text`, `select`, …), so the Home page now gets a real block editor for
  its copy while the surrounding template stays HTML. Two caveats found while
  wiring it: structured saves **rewrite the file from the schema only**, so you
  need `settings.content.merge: true` (or a `body` field) to keep the rest of the
  template; and Eleventy v3 **removed the built-in `markdownify` filter**, so the
  site registers its own via markdown-it. Blocks only help where the copy is
  data — repeated/structural markup still lives in the partial.

## Teardown

```sh
cd dev
docker-compose down -v    # stop + wipe the CMS database
rm -rf .pagescms          # remove the cloned Pages CMS app
```
