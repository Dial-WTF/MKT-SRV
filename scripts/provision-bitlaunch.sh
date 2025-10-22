#!/usr/bin/env bash
set -euo pipefail

# Requirements: curl, jq

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

if [[ -z "${BITLAUNCH_API_KEY:-}" ]]; then
  echo "ERROR: BITLAUNCH_API_KEY not set (export in shell or add to .env)." >&2
  exit 1
fi

# Config (override via env)
HOST_ID=${HOST_ID:-4}
HOST_IMAGE_ID=${HOST_IMAGE_ID:-10006}
SIZE_ID=${SIZE_ID:-nibble-4096}
REGION_ID=${REGION_ID:-chi1}
SERVER_NAME=${SERVER_NAME:-mkt-srv}

KEY_DIR="${KEY_DIR:-./tmp_ssh_keys}"
INIT_SCRIPT_PATH="${INIT_SCRIPT_PATH:-scripts/initscript.sh}"

mkdir -p "$KEY_DIR"

if [[ ! -f "$INIT_SCRIPT_PATH" ]]; then
  echo "ERROR: $INIT_SCRIPT_PATH not found." >&2
  exit 1
fi

INITSCRIPT_CONTENT=$(jq -Rs . < "$INIT_SCRIPT_PATH")

# Generate SSH key
KEY_NAME="mkt-srv-$(date +%s)"
ssh-keygen -t ed25519 -f "$KEY_DIR/$KEY_NAME" -N "" >/dev/null
PUBKEY_CONTENT=$(cat "$KEY_DIR/$KEY_NAME.pub")

echo "==> Uploading SSH key to BitLaunch..."
UPLOAD_RESPONSE=$(curl -s -X POST https://app.bitlaunch.io/api/ssh-keys \
  -H "Authorization: Bearer $BITLAUNCH_API_KEY" \
  -H "Content-Type: application/json" \
  --data "{\n    \"name\": \"$KEY_NAME\",\n    \"content\": \"$PUBKEY_CONTENT\"\n  }")

SSH_KEY_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.id')
if [[ -z "$SSH_KEY_ID" || "$SSH_KEY_ID" == "null" ]]; then
  echo "ERROR: Failed to upload SSH key: $UPLOAD_RESPONSE" >&2
  exit 1
fi
echo "==> SSH key ID: $SSH_KEY_ID"

# Create server
echo "==> Creating server on BitLaunch..."
CREATE_RESPONSE=$(curl -s 'https://app.bitlaunch.io/api/servers' \
  -H "Authorization: Bearer $BITLAUNCH_API_KEY" \
  -H "Content-Type: application/json" \
  --data "{\n    \"server\": {\n      \"name\": \"$SERVER_NAME\",\n      \"hostID\": $HOST_ID,\n      \"hostImageID\": \"$HOST_IMAGE_ID\",\n      \"sizeID\": \"$SIZE_ID\",\n      \"regionID\": \"$REGION_ID\",\n      \"sshKeys\": [\"$SSH_KEY_ID\"],\n      \"initscript\": $INITSCRIPT_CONTENT\n    }\n  }")

SERVER_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
if [[ -z "$SERVER_ID" || "$SERVER_ID" == "null" ]]; then
  echo "ERROR: Failed to create server: $CREATE_RESPONSE" >&2
  exit 1
fi
echo "==> Server ID: $SERVER_ID"

# Poll for IP
echo -n "==> Waiting for server IP "
IPV4=""
for _ in {1..40}; do
  STATUS_RESPONSE=$(curl -s "https://app.bitlaunch.io/api/servers/$SERVER_ID" \
    -H "Authorization: Bearer $BITLAUNCH_API_KEY")
  IPV4=$(echo "$STATUS_RESPONSE" | jq -r '.server.ipv4')
  if [[ "$IPV4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo ""
    echo "==> Server ready: $IPV4"
    break
  fi
  echo -n "."
  sleep 5
done

if [[ -z "$IPV4" || ! "$IPV4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "\nERROR: No IP assigned in time." >&2
  exit 1
fi

# Write Ansible inventory (INI)
ABS_KEY_PATH="$(cd "$KEY_DIR" && pwd)/$KEY_NAME"
INV_PATH="ansible/inventories/production/hosts.ini"
mkdir -p "$(dirname "$INV_PATH")"

cat > "$INV_PATH" <<EOF
[web]
mkt-srv-1 ansible_host=$IPV4 ansible_user=root ansible_ssh_private_key_file=$ABS_KEY_PATH
EOF

echo "==> Inventory updated: $INV_PATH"
echo "Export for CI: SSH_HOST=$IPV4 SSH_USER=root"
echo "Done. You can run: ansible -i $INV_PATH web -m ping"


