#!/usr/bin/env bash
# Updates the major semver tag (e.g. v1) to match the full tag (e.g. v1.2.3) with a GPG-signed tag object.
# Requires: GPG_PRIVATE_KEY, TAG, GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_ACTOR, GITHUB_WORKSPACE.
# Optional: GPG_PASSPHRASE (empty if the key has no passphrase).
set -euo pipefail

: "${TAG:?TAG is required}"
: "${GPG_PRIVATE_KEY:?GPG_PRIVATE_KEY is required}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_ACTOR:?GITHUB_ACTOR is required}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"

cd "${GITHUB_WORKSPACE}"

MINOR="${TAG%.*}"
MAJOR="${MINOR%.*}"
MESSAGE="Release ${TAG}"

export GNUPGHOME="${HOME}/.gnupg"
mkdir -p "${GNUPGHOME}"
chmod 700 "${GNUPGHOME}"

cat > "${GNUPGHOME}/gpg.conf" <<'EOF'
pinentry-mode loopback
use-agent
EOF

cat > "${GNUPGHOME}/gpg-agent.conf" <<'EOF'
allow-loopback-pinentry
allow-preset-passphrase
default-cache-ttl 7200
max-cache-ttl 7200
EOF

gpgconf --kill gpg-agent 2>/dev/null || true
gpgconf --launch gpg-agent

echo "${GPG_PRIVATE_KEY}" | gpg --batch --import

FPR="$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10; exit}')"
if [ -z "${FPR}" ]; then
  echo "No GPG secret key fingerprint found after import." >&2
  exit 1
fi

KEYGRIP="$(gpg --list-secret-keys --with-colons | awk -F: '/^grp:/ {print $10; exit}')"
if [ -z "${KEYGRIP}" ]; then
  KEYGRIP="$(gpg --list-secret-keys --with-colons | awk -F: '/^grp:/ {print $9; exit}')"
fi
if [ -z "${KEYGRIP}" ]; then
  echo "No GPG keygrip found after import." >&2
  exit 1
fi

GPG_UID="$(gpg --list-secret-keys --with-colons | awk -F: '/^uid:/ {print $10; exit}')"
if [ -n "${GPG_UID}" ]; then
  GPG_EMAIL="$(echo "${GPG_UID}" | sed -n 's/.*<\([^>]*\)>.*/\1/p')"
  GPG_NAME="$(echo "${GPG_UID}" | sed -n 's/^\(.*\) <.*/\1/p')"
  if [ -n "${GPG_EMAIL}" ]; then
    git config user.email "${GPG_EMAIL}"
  fi
  if [ -n "${GPG_NAME}" ]; then
    git config user.name "${GPG_NAME}"
  fi
fi
if [ -z "$(git config user.email || true)" ]; then
  git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
fi
if [ -z "$(git config user.name || true)" ]; then
  git config user.name "${GITHUB_ACTOR}"
fi

git config user.signingkey "${FPR}"
git config gpg.program gpg

GPG_PRESET=""
for candidate in /usr/lib/gnupg/gpg-preset-passphrase /usr/lib/gnupg2/gpg-preset-passphrase; do
  if [ -x "${candidate}" ]; then
    GPG_PRESET="${candidate}"
    break
  fi
done
if [ -z "${GPG_PRESET}" ]; then
  GPG_PRESET="$(command -v gpg-preset-passphrase || true)"
fi
if [ -z "${GPG_PRESET}" ]; then
  echo "gpg-preset-passphrase not found; install gnupg or set PATH." >&2
  exit 1
fi

if [ -n "${GPG_PASSPHRASE:-}" ]; then
  echo -n "${GPG_PASSPHRASE}" | "${GPG_PRESET}" --preset "${KEYGRIP}"
else
  echo -n | "${GPG_PRESET}" --preset "${KEYGRIP}" 2>/dev/null || true
fi

GPG_TTY="$(tty 2>/dev/null || echo "/dev/tty")"
export GPG_TTY

SERVER="${GITHUB_SERVER_URL:-https://github.com}"
SERVER="${SERVER#https://}"
SERVER="${SERVER#http://}"
git remote set-url origin "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@${SERVER}/${GITHUB_REPOSITORY}.git"

if ! git fetch origin "refs/tags/${TAG}:refs/tags/${TAG}" 2>/dev/null; then
  git fetch origin tag "${TAG}"
fi

git tag -sf "${MAJOR}" -m "${MESSAGE}" "${TAG}^{}"

git push --force origin "${MAJOR}"
