#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting Mautic Development Environment Setup..."
echo ""

# Check if .env exists
if [[ ! -f .env ]]; then
  echo "❌ .env file not found!"
  echo "Please create .env with your database passwords first."
  exit 1
fi

echo "🔐 Step 1: Generating vault password..."
bash scripts/gen-vaultpass.sh

echo "🔑 Step 2: Generating and encrypting secrets..."
ansible-playbook ansible/playbooks/prepare.yml --vault-password-file .vaultpass

echo "🐳 Step 3: Setting up Docker environment..."
bash scripts/setup-docker-dev.sh

echo "🐳 Step 4: Starting Docker containers..."
docker-compose -f docker-compose.dev.yml up -d

echo "🗄️ Step 5: Running Mautic CLI installer (auto-configures everything)..."
bash scripts/mautic-install.sh

echo ""
echo "✅ FULLY AUTOMATED SETUP COMPLETE!"
echo ""
echo "🌐 Visit: http://localhost:8000"
echo "👤 Login: admin / [from your .env MAUTIC_ADMIN_PASSWORD]"
echo ""
echo "To stop: docker-compose -f docker-compose.dev.yml down"
