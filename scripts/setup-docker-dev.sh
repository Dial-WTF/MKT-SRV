#!/usr/bin/env bash
set -euo pipefail

# Setup Docker dev environment using existing .env file
# This script ensures Docker-specific variables are set in .env

echo "🔍 Checking existing .env file..."

if [[ ! -f .env ]]; then
  echo "ERROR: .env file not found. Please create it with your database passwords."
  exit 1
fi

# Check if required Docker variables are set
if ! grep -q "MAUTIC_URL=" .env; then
  echo "📝 Adding Docker-specific variables to .env..."
  cat >> .env << 'EOF'

# Docker dev environment
MAUTIC_URL=http://localhost:8000
EOF
else
  echo "✅ .env already has Docker variables"
fi

# Show the passwords being used
echo ""
echo "🔑 Using existing passwords from .env:"
grep -E "(MYSQL_ROOT_PASSWORD|MAUTIC_DB_PASSWORD|MAUTIC_ADMIN_PASSWORD)" .env | sed 's/^/  /'
echo ""
echo "🚀 Start Docker with: task docker:up"
echo "🌐 Access Mautic at: http://localhost:8000"
echo "👤 Login: admin / [MAUTIC_ADMIN_PASSWORD from .env]"
