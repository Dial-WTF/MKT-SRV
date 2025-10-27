# Development Environment Setup

This guide shows how to set up a complete Mautic development environment using Docker with automated configuration from your existing `.env` file.

## Quick Start (Single Command)

```bash
# One command does everything!
bash scripts/setup-dev.sh

# OR if you have Go Task installed:
task docker:provision

# Visit Mautic
open http://localhost:8000
```

**That's it!** The command will:

1. Generate and encrypt vault secrets
2. Start all Docker containers
3. Configure the database automatically
4. Show you the credentials to use

## What This Does

The `task docker:provision` command:

1. **Starts Docker Stack**: Launches MariaDB, Redis, and Mautic containers
2. **Waits for Database**: Ensures MySQL is ready before proceeding
3. **Auto-Configures Database**: Creates the `mautic` user and database using credentials from your `.env` file
4. **Shows Credentials**: Displays the exact database and admin credentials to use in the Mautic web interface

## Prerequisites

- **Docker Desktop** installed and running
- **Task** (Go Task) installed: `brew install go-task/tap/go-task`
- **Your `.env` file** with database passwords (you already have this)

## Environment Variables Used

The system reads from your existing `.env` file:

```bash
# Database (required)
MYSQL_ROOT_PASSWORD=your_root_password
MAUTIC_DB_PASSWORD=your_mautic_password

# Mautic Admin (required)
MAUTIC_ADMIN_PASSWORD=your_admin_password
MAUTIC_ADMIN_EMAIL=admin@example.com

# Optional
MYSQL_DATABASE=mautic  # defaults to 'mautic'
MAUTIC_ADMIN_USER=admin  # defaults to 'admin'
MAUTIC_URL=http://localhost:8000  # auto-configured
```

## Available Commands

```bash
# 🚀 Complete automated setup (recommended)
task docker:provision    # Does everything in one command

# Individual steps (if you need manual control)
task docker:up         # Start containers only
task docker:logs       # View logs
task docker:down       # Stop everything

# Production deployment
task bl:provision      # Create production server
task deploy:localdb    # Deploy to production
```

## Why This Approach

This automated approach:

- **Uses your existing `.env` file** - no need to recreate credentials
- **Integrates with Ansible vault** - same secrets for dev and production
- **Leverages MySQL initialization** - database setup happens automatically
- **Zero manual configuration** - everything happens when containers start
- **Shows exact credentials** - no guessing what to enter in the web interface

**Database Automation:**

- The `init-db.sql` template runs automatically when MySQL starts
- Passwords from your `.env` are substituted into the SQL template
- No authentication issues or manual database setup required

## Database Credentials

When you visit the Mautic setup page (http://localhost:8000), use these credentials:

- **Database Driver**: MySQL PDO (Recommended)
- **Database Host**: `db`
- **Database Port**: `3306`
- **Database Name**: `mautic` (or value from `MYSQL_DATABASE`)
- **Database Username**: `mautic`
- **Database Password**: Your `MAUTIC_DB_PASSWORD` from `.env`
- **Database Table Prefix**: `bak_`

## Admin Login

After completing the web setup:

- **URL**: http://localhost:8000
- **Username**: `admin` (or `MAUTIC_ADMIN_USER` from .env)
- **Password**: Your `MAUTIC_ADMIN_PASSWORD` from `.env`

## Troubleshooting

### Database Connection Issues

If Mautic can't connect to the database:

```bash
# Check database logs
task docker:logs

# Verify database is running
docker ps

# Manual database setup (if needed)
bash scripts/init-db.sh
```

### Port Conflicts

If port 8000 is in use:

1. **Find what's using it**: `lsof -i :8000`
2. **Stop the conflicting service**, or
3. **Change the port** in `docker-compose.dev.yml`

### Reset Everything

```bash
# Stop and remove all containers/volumes
task docker:down
docker system prune -a --volumes

# Start fresh
task docker:provision
```

## Production Deployment

When ready to deploy to production:

```bash
# 1. Create production server
task bl:provision

# 2. Deploy Mautic
task deploy:localdb

# 3. Enable HTTPS (when DNS is ready)
ansible-playbook -i ansible/inventories/production/hosts.ini ansible/playbooks/site.yml \
  --vault-password-file .vaultpass \
  -e enable_letsencrypt=true -e domain="yourdomain.com" -e letsencrypt_email="you@example.com"
```

## File Structure

```
mkt-srv/
├── .env                          # Your existing environment file
├── docker-compose.dev.yml        # Docker stack configuration
├── scripts/
│   ├── init-db.sh               # Database initialization script
│   └── setup-docker-dev.sh      # Environment setup script
├── ansible/                     # Production deployment
└── docs/
    └── DEV_ENVIRONMENT.md       # This file
```

## Security Notes

- **Development Only**: This setup is for development/testing only
- **No SSL**: HTTP only (add HTTPS for production)
- **Local Database**: MariaDB runs locally in Docker
- **Vault Integration**: Uses your existing vault secrets for consistency

## Support

If you encounter issues:

1. Check logs: `task docker:logs`
2. Verify .env file exists with required variables
3. Ensure Docker Desktop is running
4. Check port availability: `lsof -i :8000`
