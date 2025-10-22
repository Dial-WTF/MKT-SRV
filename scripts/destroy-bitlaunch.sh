#!/usr/bin/env bash
set -euo pipefail

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

if [[ -z "${BITLAUNCH_API_KEY:-}" ]]; then
  echo "ERROR: BITLAUNCH_API_KEY not set (export in shell or add to .env)." >&2
  exit 1
fi

SERVER_IP=${1:-}
if [[ -z "$SERVER_IP" ]]; then
  echo "Usage: $0 <server_ip>" >&2
  exit 1
fi

echo "==> Locating server by IP $SERVER_IP ..."
SERVER_LIST=$(curl -s -H "Authorization: Bearer $BITLAUNCH_API_KEY" https://app.bitlaunch.io/api/servers)
SERVER_ID=$(echo "$SERVER_LIST" | jq -r ".[] | select(.ipv4 == \"$SERVER_IP\") | .id")

if [[ -z "$SERVER_ID" ]]; then
  echo "ERROR: Could not find server with IP $SERVER_IP" >&2
  exit 1
fi

echo "==> Destroying server $SERVER_ID ($SERVER_IP) ..."
curl -s -X DELETE -H "Authorization: Bearer $BITLAUNCH_API_KEY" "https://app.bitlaunch.io/api/servers/$SERVER_ID" >/dev/null
echo "==> Server destroyed. Remember to update ansible inventory if needed."


