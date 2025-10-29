# Mautic Server Project - Current State

## Project Overview
This is a Mautic marketing automation server deployment project with both local Docker development environment and production Ansible deployment.

## Current Status: **BROKEN - Database Connection Issues**

### What's Working
- ✅ Local Docker development environment (fully automated)
- ✅ Production server provisioning (BitLaunch + Ansible)
- ✅ All services installed (Nginx, PHP-FPM, MariaDB, Redis)
- ✅ Database and user created with correct credentials
- ✅ Mautic application deployed
- ✅ Configuration files created with correct database credentials

### What's Broken
- ❌ **Mautic cannot connect to database** - getting "Access denied for user ''@'localhost' (using password: NO)"
- ❌ **Web interface returns 500 Internal Server Error**
- ❌ **Mautic is reading empty database credentials despite correct config files**

## Root Cause Analysis
Mautic is somehow reading empty database credentials even though:
- `config/local.php` has correct credentials: `db_user => 'mautic'`, `db_password => 'cp5eotw22jtsjw!uasz9ys97ggyr3'`
- `config/parameters.php` has correct credentials
- No `.env.local` file exists (we removed it)
- Database user `mautic` exists with correct password

## Key Files & Locations

### Production Server
- **IP**: `162.33.178.90`
- **SSH Key**: `/Users/adammanka/Desktop/DevRepos/mkt-srv/tmp_ssh_keys/mkt-srv-1761713284`
- **Mautic Path**: `/opt/mautic/apps/mautic/current/`
- **Web Root**: `/var/www/html` (symlink to Mautic docroot)
- **Config Files**: 
  - `/opt/mautic/apps/mautic/current/config/local.php` ✅ (correct credentials)
  - `/opt/mautic/apps/mautic/current/config/parameters.php` ✅ (correct credentials)

### Database
- **Host**: `127.0.0.1:3306`
- **Database**: `mautic`
- **User**: `mautic`
- **Password**: `cp5eotw22jtsjw!uasz9ys97ggyr3`
- **Root Password**: `b!zs!6l!ehkvzonkza35otnfc!282u`

### Vault Credentials
```yaml
mautic:
  admin_password: 'l6ibq0qrlwqgjqjc'
  admin_email: 'info@dial.wtf'
  secret_key: 'mautic-secret-key-change-in-production'
  db:
    password: 'cp5eotw22jtsjw!uasz9ys97ggyr3'
    db_root_password: 'b!zs!6l!ehkvzonkza35otnfc!282u'
```

## Recent Changes Made
1. **Removed `.env.local` creation** from Ansible role (was causing conflicts)
2. **Added explicit `.env.local` removal** task
3. **Created `config/local.php`** with correct database credentials
4. **Cleared Mautic cache** to force config reload

## Commands to Run

### Check Current Status
```bash
# Test web interface
curl -I http://162.33.178.90

# Check Mautic config
ssh -i /Users/adammanka/Desktop/DevRepos/mkt-srv/tmp_ssh_keys/mkt-srv-1761713284 root@162.33.178.90 "cat /opt/mautic/apps/mautic/current/config/local.php"

# Test database connection
ssh -i /Users/adammanka/Desktop/DevRepos/mkt-srv/tmp_ssh_keys/mkt-srv-1761713284 root@162.33.178.90 "mysql -u mautic -p'cp5eotw22jtsjw!uasz9ys97ggyr3' -e 'SELECT 1'"
```

### Redeploy (if needed)
```bash
task deploy:localdb
```

## SOLUTION FOUND!

The issue is that Mautic uses environment variables with the `MAUTIC_` prefix (e.g., `MAUTIC_DB_USER`, `MAUTIC_DB_PASSWORD`), not just `DB_USER`, `DB_PASSWORD`. The configuration file `docroot/app/config/parameters.php` loads these variables.

### Fix Applied to Ansible Role
Updated `ansible/roles/mautic/tasks/main.yml` to:
1. Configure `.env` file with `MAUTIC_` prefixed environment variables
2. Create `local.php` in the correct location: `docroot/app/config/local.php` (not just `config/local.php`)

### To Apply the Fix
Run: `task deploy:localdb`

This will:
- Update the `.env` file with correct `MAUTIC_DB_*` variables
- Create the `local.php` config in the correct location
- Clear cache and run migrations

## Project Structure
```
mkt-srv/
├── ansible/                    # Production deployment
│   ├── roles/
│   │   ├── mautic/            # Mautic deployment role
│   │   ├── mariadb/           # Database setup
│   │   ├── nginx/             # Web server
│   │   └── php/               # PHP-FPM
│   ├── inventories/production/
│   └── group_vars/secrets.vault.yml
├── scripts/                    # Automation scripts
├── docker-compose.dev.yml     # Local development
├── Taskfile.yml              # Task runner
└── .env                      # Local environment variables
```

## Key Issue
**Mautic is reading empty database credentials despite having correct configuration files.** This suggests either:
- Mautic's configuration loading is broken
- There's a caching issue
- There's another config file we haven't found
- Database user permissions are wrong
- Mautic is not reading the config files we think it should

The error "Access denied for user ''@'localhost' (using password: NO)" shows Mautic is trying to connect with an empty username and no password, which means it's not reading our config files at all.
