#!/usr/bin/env bash
set -euo pipefail

# Setup GitHub repository secrets for CI/CD
# Requires: gh CLI (brew install gh)

echo "🔐 GitHub Secrets Setup for MKT-SRV"
echo ""

# Check if gh is installed
if ! command -v gh &> /dev/null; then
  echo "❌ GitHub CLI (gh) is not installed"
  echo "Install: brew install gh"
  exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
  echo "🔑 Please authenticate with GitHub first:"
  gh auth login
fi

echo "📋 This script will set the following secrets:"
echo "  - ANSIBLE_VAULT_PASSWORD"
echo "  - BITLAUNCH_API_KEY (optional)"
echo "  - DOMAIN"
echo "  - EMAIL"
echo "  - SSH_HOST (after server provision)"
echo "  - SSH_USER"
echo "  - SSH_KEY (after server provision)"
echo ""

# ANSIBLE_VAULT_PASSWORD
if [[ -f .vaultpass ]]; then
  echo "✅ Found .vaultpass - setting ANSIBLE_VAULT_PASSWORD..."
  gh secret set ANSIBLE_VAULT_PASSWORD < .vaultpass
  echo "✅ ANSIBLE_VAULT_PASSWORD set"
else
  echo "⚠️  .vaultpass not found - run: task gen:vaultpass"
fi

# BITLAUNCH_API_KEY
if [[ -f .env ]] && grep -q "BITLAUNCH_API_KEY" .env; then
  BITLAUNCH_KEY=$(grep BITLAUNCH_API_KEY .env | cut -d'=' -f2-)
  if [[ -n "$BITLAUNCH_KEY" && "$BITLAUNCH_KEY" != "your_key_here" ]]; then
    echo "✅ Found BITLAUNCH_API_KEY in .env - setting secret..."
    echo "$BITLAUNCH_KEY" | gh secret set BITLAUNCH_API_KEY
    echo "✅ BITLAUNCH_API_KEY set"
  fi
fi

# DOMAIN
read -p "Enter your domain (e.g., mautic.yourdomain.com): " DOMAIN
if [[ -n "$DOMAIN" ]]; then
  echo "$DOMAIN" | gh secret set DOMAIN
  echo "✅ DOMAIN set to: $DOMAIN"
fi

# EMAIL
read -p "Enter your email for Let's Encrypt: " EMAIL
if [[ -n "$EMAIL" ]]; then
  echo "$EMAIL" | gh secret set EMAIL
  echo "✅ EMAIL set to: $EMAIL"
fi

# SSH_USER
read -p "Enter SSH username (default: root): " SSH_USER
SSH_USER=${SSH_USER:-root}
echo "$SSH_USER" | gh secret set SSH_USER
echo "✅ SSH_USER set to: $SSH_USER"

echo ""
echo "🚀 Secrets configured!"
echo ""
echo "⏭️  Next steps:"
echo "  1. Provision server: task bl:provision"
echo "  2. Get server IP from output"
echo "  3. Set SSH_HOST and SSH_KEY:"
echo "     gh secret set SSH_HOST -b\"YOUR_SERVER_IP\""
echo "     gh secret set SSH_KEY < tmp_ssh_keys/YOUR_KEY_FILE"
echo "  4. Push to main to trigger deployment"
echo ""

