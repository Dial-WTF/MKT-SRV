#!/bin/bash
set -e

echo "🗄️ Initializing Mautic database..."

# Create the mautic user with the password from environment
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
    CREATE USER IF NOT EXISTS 'mautic'@'%' IDENTIFIED BY '${MAUTIC_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO 'mautic'@'%';
    FLUSH PRIVILEGES;
    SELECT 'Database and user created successfully!' as status;
EOSQL

echo "✅ Database initialized for Mautic"

