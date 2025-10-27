#!/usr/bin/env bash
set -euo pipefail

# Requires: multipass, jq, ssh-keygen

VM_NAME=${VM_NAME:-mkt-dev}
VM_IMAGE=${VM_IMAGE:-24.04}
VM_CPUS=${VM_CPUS:-2}
VM_MEM=${VM_MEM:-4G}
VM_DISK=${VM_DISK:-20G}
KEY_DIR=${KEY_DIR:-./tmp_ssh_keys}

mkdir -p "$KEY_DIR"

KEY_NAME="${VM_NAME}-$(date +%s)"
ssh-keygen -t ed25519 -f "$KEY_DIR/$KEY_NAME" -N "" >/dev/null
PUBKEY_CONTENT=$(cat "$KEY_DIR/$KEY_NAME.pub")

TMP_CLOUD_INIT=$(mktemp)
cat > "$TMP_CLOUD_INIT" <<EOF
#cloud-config
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh-authorized-keys:
      - ${PUBKEY_CONTENT}
package_update: true
packages:
  - curl
  - ca-certificates
  - git
  - jq
  - ufw
runcmd:
  - ufw allow OpenSSH || true
  - ufw --force enable || true
EOF

echo "==> Launching Multipass VM $VM_NAME ..."
if multipass info "$VM_NAME" >/dev/null 2>&1; then
  echo "VM $VM_NAME already exists. Skipping launch."
else
  multipass launch -n "$VM_NAME" "$VM_IMAGE" --cpus "$VM_CPUS" --memory "$VM_MEM" --disk "$VM_DISK" --cloud-init "$TMP_CLOUD_INIT"
fi

rm -f "$TMP_CLOUD_INIT"

echo "==> Fetching VM IP ..."
IP=$(multipass info "$VM_NAME" --format json | jq -r --arg name "$VM_NAME" '.info[$name].ipv4[0]')
if [[ -z "$IP" || "$IP" == "null" ]]; then
  echo "ERROR: could not determine VM IP" >&2
  exit 1
fi
echo "VM IP: $IP"

INV_PATH="ansible/inventories/dev/hosts.ini"
mkdir -p "$(dirname "$INV_PATH")"
ABS_KEY_PATH="$(cd "$KEY_DIR" && pwd)/$KEY_NAME"

cat > "$INV_PATH" <<EOF
[web]
${VM_NAME} ansible_host=${IP} ansible_user=ubuntu ansible_ssh_private_key_file=${ABS_KEY_PATH}
EOF

echo "==> Wrote inventory: $INV_PATH"
echo "You can now run: ansible -i $INV_PATH web -m ping"


