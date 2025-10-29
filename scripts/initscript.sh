#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
apt-get install -y curl ca-certificates git jq ufw screen ranger htop python3 python3-pip ansible

# Install go-task (Taskfile runner)
if ! command -v task >/dev/null 2>&1; then
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) TARCH=amd64 ;;
    aarch64|arm64) TARCH=arm64 ;;
    *) TARCH=amd64 ;;
  esac
  TMP_TGZ=/tmp/go-task.tar.gz
  curl -fsSL "https://github.com/go-task/task/releases/latest/download/task_linux_${TARCH}.tar.gz" -o "$TMP_TGZ" || true
  if [ -s "$TMP_TGZ" ]; then
    tar -C /usr/local/bin -xzf "$TMP_TGZ" task || true
    chmod +x /usr/local/bin/task || true
  fi
fi

# Install MariaDB and configure for socket-based root access
apt-get install -y mariadb-server || true

# Configure MariaDB for socket-based root access (no password required)
if [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]; then
  # Ensure socket-based authentication is enabled
  sed -i 's/^#\?user\s*=.*/user = mysql/' /etc/mysql/mariadb.conf.d/50-server.cnf || true
fi

# Start MariaDB if not running
systemctl start mariadb || true
systemctl enable mariadb || true

# Configure MariaDB for socket-based root access
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;" || true
mysql -e "FLUSH PRIVILEGES;" || true

# Enable UFW basics
ufw allow OpenSSH || true
ufw --force enable || true

echo "Init script complete"


