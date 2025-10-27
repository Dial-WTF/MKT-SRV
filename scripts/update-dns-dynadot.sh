#!/usr/bin/env bash
set -euo pipefail

# Update Dynadot DNS A record after server provision
# Requires: DYNADOT_API_KEY in .env

if [[ ! -f .env ]]; then
  echo "❌ .env file not found!"
  exit 1
fi

source .env

if [[ -z "${DYNADOT_API_KEY:-}" ]]; then
  echo "❌ DYNADOT_API_KEY not set in .env"
  exit 1
fi

# Get server IP from inventory
if [[ ! -f ansible/inventories/production/hosts.ini ]]; then
  echo "❌ Production inventory not found. Run: task bl:provision first"
  exit 1
fi

SERVER_IP=$(grep ansible_host ansible/inventories/production/hosts.ini | awk '{print $2}' | cut -d'=' -f2)

if [[ -z "$SERVER_IP" ]]; then
  echo "❌ Could not find server IP in inventory"
  exit 1
fi

# Prompt for subdomain
read -p "Enter subdomain (e.g., mautic for mautic.yourdomain.com): " SUBDOMAIN
read -p "Enter root domain (e.g., yourdomain.com): " ROOT_DOMAIN

echo ""
echo "📋 DNS Update:"
echo "  Record: ${SUBDOMAIN}.${ROOT_DOMAIN}"
echo "  Type: A"
echo "  Value: ${SERVER_IP}"
echo ""
read -p "Proceed with DNS update? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "❌ Canceled"
  exit 0
fi

echo "🌐 Updating DNS via Dynadot API..."

# Dynadot API endpoint (adjust based on their API docs)
# Note: You'll need to whitelist your current IP in Dynadot settings first
RESPONSE=$(curl -s "https://api.dynadot.com/api3.json?key=${DYNADOT_API_KEY}&command=set_dns2&domain=${ROOT_DOMAIN}&subdomain=${SUBDOMAIN}&record_type=A&address=${SERVER_IP}")

if echo "$RESPONSE" | grep -q "successfully"; then
  echo "✅ DNS updated successfully!"
  echo ""
  echo "⏳ Waiting for DNS propagation (this may take 5-10 minutes)..."
  echo "Check with: dig ${SUBDOMAIN}.${ROOT_DOMAIN}"
  echo ""
  echo "Once propagated, enable HTTPS:"
  echo "  ansible-playbook -i ansible/inventories/production/hosts.ini ansible/playbooks/site.yml \\"
  echo "    --vault-password-file .vaultpass \\"
  echo "    -e enable_letsencrypt=true -e domain=\"${SUBDOMAIN}.${ROOT_DOMAIN}\" -e letsencrypt_email=\"you@example.com\""
else
  echo "❌ DNS update failed:"
  echo "$RESPONSE"
  exit 1
fi

