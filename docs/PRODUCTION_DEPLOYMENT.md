# Production Deployment Guide

This guide shows how to deploy vanilla Mautic to production using BitLaunch and Ansible.

## Prerequisites

- BitLaunch account with API key
- Domain name with DNS access
- GitHub repository with secrets configured
- Ansible installed locally: `pip install ansible`
- Go Task installed: `brew install go-task/tap/go-task`

## Quick Start (Production)

### 1. Configure GitHub Secrets

**Option A: Automated (recommended)**

```bash
# Install GitHub CLI if needed
brew install gh

# Run the setup script
task gh:secrets

# Follow prompts to set:
# - ANSIBLE_VAULT_PASSWORD (from .vaultpass)
# - BITLAUNCH_API_KEY (from .env)
# - DOMAIN (your domain)
# - EMAIL (for Let's Encrypt)
# - SSH_USER (usually 'root')
```

**Option B: Manual**

In your repository settings (Settings → Secrets → Actions), add:

- `BITLAUNCH_API_KEY` - Your BitLaunch API key
- `ANSIBLE_VAULT_PASSWORD` - Contents of your `.vaultpass` file
- `DOMAIN` - Your domain (e.g., mautic.yourdomain.com)
- `EMAIL` - Your email for Let's Encrypt notifications
- `SSH_USER` - Usually `root` or `ubuntu`

### 2. Provision Production Server

```bash
# Set your BitLaunch API key
export BITLAUNCH_API_KEY=your_api_key_here

# Create server and write inventory
task bl:provision

# This creates ansible/inventories/production/hosts.ini with the server IP
```

### 3. Test Connectivity

```bash
# Ping the server
task ping

# Should see:
# mkt-srv-1 | SUCCESS => { "ping": "pong" }
```

### 4. Deploy Mautic (HTTP-first)

```bash
# Deploy with local MariaDB
task deploy:localdb

# This installs:
# - Nginx
# - PHP 8.2 + FPM
# - MariaDB (local)
# - Redis
# - Mautic (via Composer)
```

### 5. Complete Web Installer

Visit `http://YOUR_SERVER_IP/installer` and use credentials from:

```bash
# View vault secrets
ansible-vault view ansible/group_vars/secrets.vault.yml --vault-password-file .vaultpass
```

**Database credentials:**

- Host: `127.0.0.1`
- Port: `3306`
- Database: `mautic`
- Username: `mautic`
- Password: `[from vault: mautic.db.password]`
- Table Prefix: Leave empty or use `m_`

**Admin user:**

- Username: `admin`
- Password: `[from vault: mautic.admin_password]`
- Email: `[from group_vars/all.yml: mautic.admin_email]`

### 6. Point DNS to Server

**Option A: Automated (Dynadot API)**

```bash
# Add to .env:
# DYNADOT_API_KEY=your_key_here

# Update DNS automatically
task dns:update

# Follow prompts for subdomain and root domain
```

**Option B: Manual**

Update your DNS A record in Dynadot:
- Record: `mautic` (or your subdomain)
- Type: `A`
- Value: `YOUR_SERVER_IP` (from step 2)
- TTL: `300` (5 minutes)

Wait for propagation: `dig mautic.yourdomain.com`

### 7. Enable HTTPS

```bash
ansible-playbook -i ansible/inventories/production/hosts.ini ansible/playbooks/site.yml \
  --vault-password-file .vaultpass \
  -e enable_letsencrypt=true -e domain="mautic.yourdomain.com" -e letsencrypt_email="you@example.com"
```

This will:

- Install Let's Encrypt certificate
- Configure Nginx for HTTPS
- Redirect HTTP → HTTPS

### 7. Verify

Visit `https://mautic.yourdomain.com` and login with your admin credentials.

## CI/CD (GitHub Actions)

Every push to `main` triggers `.github/workflows/deploy.yml`:

1. Connects to your production server via SSH
2. Runs the Ansible playbook
3. Updates Mautic if needed
4. Renews SSL certificates

**Update GitHub Secrets:**

After provisioning, update these in GitHub:

- `SSH_HOST` - Your server IP (from `task bl:provision` output)
- `SSH_USER` - `root` (or `ubuntu` depending on your setup)
- `SSH_KEY` - Your SSH private key from `tmp_ssh_keys/`

## External Database Migration (Optional)

If you want to move to a managed database later:

### 1. Backup Current Database

```bash
# SSH into server
ssh -i tmp_ssh_keys/YOUR_KEY root@YOUR_IP

# Dump database
mysqldump -u root -p --single-transaction --routines --triggers mautic > mautic.sql

# Download backup
exit
scp -i tmp_ssh_keys/YOUR_KEY root@YOUR_IP:~/mautic.sql ./
```

### 2. Create External Database

- Create a MariaDB/MySQL instance (Railway, PlanetScale, RDS, etc.)
- Import the dump:
  ```bash
  mysql -h external-host -u mautic -p mautic < mautic.sql
  ```

### 3. Update Ansible Variables

Edit `ansible/group_vars/all.yml`:

```yaml
db_backend: external
```

Add to `ansible/group_vars/secrets.vault.yml`:

```yaml
db_host: external-db-host.com
db_port: 3306
db_name: mautic
db_user: mautic
db_password: your_external_db_password
```

Re-encrypt:

```bash
ansible-vault encrypt ansible/group_vars/secrets.vault.yml --vault-password-file .vaultpass
```

### 4. Redeploy

```bash
task deploy:externaldb DB_HOST=external-host DB_NAME=mautic DB_USER=mautic
```

## Maintenance

### Update Mautic

```bash
# SSH into server
ssh -i tmp_ssh_keys/YOUR_KEY root@YOUR_IP

# Update
cd /opt/mautic/apps/mautic/current
composer update
php bin/console doctrine:migrations:migrate --no-interaction
php bin/console cache:clear

# Or redeploy via Ansible
task deploy:localdb
```

### View Logs

```bash
# Nginx
ssh root@YOUR_IP "tail -f /var/log/nginx/error.log"

# PHP-FPM
ssh root@YOUR_IP "tail -f /var/log/php8.2-fpm.log"

# Mautic cron
ssh root@YOUR_IP "tail -f /opt/mautic/logs/cron.log"
```

### Backup Strategy

Add to your Ansible playbook or run manually:

```bash
# Daily backup script
0 2 * * * mysqldump -u root -p'PASSWORD' mautic | gzip > /backups/mautic-$(date +\%Y\%m\%d).sql.gz
```

## Troubleshooting

### Can't SSH to server

```bash
# Check firewall
ssh root@YOUR_IP "ufw status"

# Check SSH service
ssh root@YOUR_IP "systemctl status ssh"
```

### Mautic not accessible

```bash
# Check Nginx
ssh root@YOUR_IP "systemctl status nginx"
ssh root@YOUR_IP "nginx -t"

# Check PHP-FPM
ssh root@YOUR_IP "systemctl status php8.2-fpm"

# Check permissions
ssh root@YOUR_IP "ls -la /opt/mautic/apps/mautic/current"
```

### SSL Certificate Issues

```bash
# Renew manually
ssh root@YOUR_IP "certbot renew --nginx"

# Check expiry
ssh root@YOUR_IP "certbot certificates"
```

## Architecture

```
Production Server (BitLaunch)
├── Nginx (reverse proxy + SSL)
├── PHP 8.2-FPM (Mautic pool)
├── MariaDB (local or external)
├── Redis (caching)
└── Mautic (Composer-based install)
```

## Security Notes

- ✅ UFW firewall enabled (SSH + HTTP/HTTPS only)
- ✅ SSL/TLS via Let's Encrypt
- ✅ Secrets encrypted with Ansible Vault
- ✅ Non-root PHP-FPM user (www-data)
- ✅ SSH key-based authentication

## Cost Estimate (BitLaunch)

- **Basic**: nibble-4096 (~$20/month) - 4GB RAM, 2 CPU
- **Recommended**: nibble-8192 (~$40/month) - 8GB RAM, 4 CPU
- **High Traffic**: custom sizing available

## Next Steps

1. Set up monitoring (optional)
2. Configure email sending (SMTP/Resend API)
3. Add backup automation
4. Set up staging environment
5. Configure CDN for assets (optional)
