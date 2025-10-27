#!/usr/bin/env bash
set -euo pipefail

# Generate a strong random vault password and write to .vaultpass
# Usage: bash scripts/gen-vaultpass.sh [length]

length=${1:-32}

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl is required" >&2
  exit 1
fi

# Create parent dir if running from nested path
repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

pass=$(openssl rand -base64 64 | tr -dc 'A-Za-z0-9' | head -c "$length")
printf '%s' "$pass" > .vaultpass
chmod 600 .vaultpass || true

echo ".vaultpass created (length: $length, mode: 600)."

