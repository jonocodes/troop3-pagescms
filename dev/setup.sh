#!/usr/bin/env bash
# Clone + configure a local Pages CMS instance (pinned tag), backed by the
# Postgres in docker-compose.yml.
#
# Run from this folder:  ./setup.sh
# Idempotent: re-running keeps .env.local and only installs what's missing.
#
# What is NOT scripted: creating the GitHub App (step 4 below). That step opens
# a browser and needs your GitHub account, so run it by hand once.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMS_DIR="$HERE/.pagescms"
CMS_TAG="2.1.8"
DB_URL="postgresql://pagescms:pagescms@localhost:55432/pagescms"

if [ ! -d "$CMS_DIR/.git" ]; then
  echo "==> cloning pages-cms $CMS_TAG into $CMS_DIR"
  git clone --branch "$CMS_TAG" --depth 1 https://github.com/pagescms/pagescms.git "$CMS_DIR"
else
  echo "==> $CMS_DIR already cloned"
fi

# Workarounds for GitHub's App manifest validation in pages-cms 2.1.8's helper:
#   - `hook_attributes.secret` is not a permitted key
#   - webhook URLs that aren't publicly reachable (localhost) are rejected outright
#   - `email_addresses` is not a permission resource name; GitHub's is `emails`
# The helper file is reset to the pinned tag first, so re-running is safe.
PATCH="$HERE/patches/pagescms-2.1.8-github-manifest-validation.patch"
echo "==> applying GitHub manifest validation workarounds"
git -C "$CMS_DIR" checkout -- scripts/setup-github-app.mjs
git -C "$CMS_DIR" apply "$PATCH"

cd "$CMS_DIR"

if [ ! -d node_modules ]; then
  echo "==> npm install"
  npm install
else
  echo "==> node_modules present"
fi

gen_secret() {
  # openssl is not always on PATH (e.g. NixOS); node is, we just installed it
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32
  else
    node -e "process.stdout.write(require('crypto').randomBytes(32).toString('base64'))"
  fi
}

if [ ! -f .env.local ] || grep -qE '^(BETTER_AUTH_SECRET|CRYPTO_KEY)=$' .env.local; then
  echo "==> writing .env.local"
  cat > .env.local <<EOF
DATABASE_URL=$DB_URL
BETTER_AUTH_SECRET=$(gen_secret)
CRYPTO_KEY=$(gen_secret)
EOF
else
  echo "==> .env.local present (leaving it alone)"
fi

echo "==> database migrations"
npm run db:migrate

cat <<EOF

==> ready. Two manual steps, then the CMS is up (both run inside $CMS_DIR):

  1. Create the GitHub App for this local instance (browser flow, once):
       cd "$CMS_DIR"
       npm run setup:github-app -- --base-url http://localhost:3000 --env .env.local
     If no browser opens, visit the URL it prints (default http://127.0.0.1:8787/start)
     and click "Create GitHub App". This writes the GITHUB_APP_* vars into .env.local.
  2. Start the CMS (same folder):
       npm run dev
     Open http://localhost:3000 and sign in with GitHub.

The repo being edited is picked inside the app; it must be a GitHub repo whose
root contains the site's .pages.yml (see ../README.md).
EOF
