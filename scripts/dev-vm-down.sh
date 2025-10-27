#!/usr/bin/env bash
set -euo pipefail

VM_NAME=${VM_NAME:-mkt-dev}

if multipass info "$VM_NAME" >/dev/null 2>&1; then
  echo "==> Deleting Multipass VM $VM_NAME ..."
  multipass delete "$VM_NAME"
  multipass purge
else
  echo "VM $VM_NAME not found."
fi

echo "Done."


