#!/bin/bash
set -e

echo "🔧 Mautic Auto-Installer Starting..."
echo "Waiting for Mautic container to be ready..."

# Wait for Mautic to be accessible
for i in {1..60}; do
  if curl -sf http://localhost:8000 > /dev/null 2>&1; then
    echo "✅ Mautic container is responding"
    break
  fi
  echo -n "."
  sleep 2
done

echo ""
echo "⏳ Waiting for Mautic files to initialize..."
sleep 5

# Load credentials from .env first
if [[ ! -f .env ]]; then
  echo "❌ .env file not found!"
  exit 1
fi

set -a
source .env
set +a

DB_NAME=${MYSQL_DATABASE:-mautic}
DB_PASS=${MAUTIC_DB_PASSWORD}
ADMIN_PASS=${MAUTIC_ADMIN_PASSWORD}
ADMIN_EMAIL=${MAUTIC_ADMIN_EMAIL}
DB_ROOT_PASS=${MYSQL_ROOT_PASSWORD}

# Check if database has Mautic tables (real install check)
echo "🔍 Checking if Mautic tables exist in database..."
TABLES_EXIST=$(docker exec mkt-srv-db-1 mysql -u root -p"${DB_ROOT_PASS}" -D "$DB_NAME" -e "SHOW TABLES LIKE 'bak_users';" 2>/dev/null | grep -c "bak_users" || echo "0")
TABLES_EXIST=$(echo "$TABLES_EXIST" | tr -d '\n\r' | head -c 1)

echo "📊 Tables check result: '$TABLES_EXIST'"

if [[ "$TABLES_EXIST" == "1" ]]; then
  echo "✅ Mautic is already installed (database tables exist)!"
  echo "🌐 Visit http://localhost:8000"
  echo "👤 Login: admin / ${ADMIN_PASS}"
  exit 0
fi

echo "🔧 Mautic NOT installed - proceeding with CLI installer..."

# First, ensure the mautic user exists in the database
echo "🔐 Ensuring database user exists..."
echo "Creating user 'mautic' with password from .env..."

# Create SQL commands in a temp file to avoid quoting issues
cat > /tmp/create-user.sql <<EOSQL
DROP USER IF EXISTS 'mautic'@'%';
CREATE USER 'mautic'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO 'mautic'@'%';
FLUSH PRIVILEGES;
SELECT User, Host FROM mysql.user WHERE User='mautic';
EOSQL

# Execute the SQL with proper authentication
if docker exec -i mkt-srv-db-1 mysql -u root -p"${DB_ROOT_PASS}" -D "${DB_NAME}" < /tmp/create-user.sql; then
  echo "✅ Database user 'mautic' created successfully!"
  rm -f /tmp/create-user.sql
else
  echo "❌ Failed to create database user!"
  cat /tmp/create-user.sql
  exit 1
fi

echo "🗄️ Installing Mautic via CLI..."
echo "Running: mautic:install with your .env credentials..."

# Run Mautic installer (with correct working directory and syntax)
if docker exec -w /var/www/html mkt-srv-mautic-1 php bin/console mautic:install \
  http://localhost:8000 \
  --db_driver=pdo_mysql \
  --db_host=db \
  --db_port=3306 \
  --db_name="${DB_NAME}" \
  --db_user=mautic \
  --db_password="${DB_PASS}" \
  --db_table_prefix=bak_ \
  --admin_username=admin \
  --admin_password="${ADMIN_PASS}" \
  --admin_email="${ADMIN_EMAIL}" \
  --force \
  --no-interaction 2>&1 | tee /tmp/mautic-install.log; then
  
  echo "✅ Mautic installed successfully!"
  echo ""
  echo "🌐 Visit: http://localhost:8000"
  echo "👤 Login:"
  echo "  Username: admin"
  echo "  Password: ${ADMIN_PASS}"
  echo ""
else
  echo "⚠️ Mautic install command completed with warnings"
  echo "📋 Check logs: /tmp/mautic-install.log"
  echo ""
  echo "🌐 Visit: http://localhost:8000"
  echo "👤 If login page appears, use:"
  echo "  Username: admin"
  echo "  Password: ${ADMIN_PASS}"
  echo ""
fi

