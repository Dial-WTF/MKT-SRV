#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
apt-get install -y curl ca-certificates git jq ufw

# Enable UFW basics
ufw allow OpenSSH || true
ufw --force enable || true

echo "Init script complete"


