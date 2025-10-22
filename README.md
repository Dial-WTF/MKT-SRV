# MKT-SRV – Vanilla Mautic (Single Host)

Provision a vanilla Mautic stack on one Ubuntu host via Ansible. Defaults to HTTP-only for fast bootstrap; enable Let’s Encrypt either during provision (if DNS is ready) or after initial install. Database runs on the same host (local MariaDB). A clean path is provided to migrate to an external/managed MariaDB later.

## Repository layout

```
ansible/
  inventories/
    production/hosts.ini
  group_vars/
    all.yml
    secrets.vault.yml   # encrypt with ansible-vault
  roles/
    common/
    nginx/
    php/
    mariadb/
    redis/
    mautic/
  playbooks/
    site.yml
  ansible.cfg
.github/workflows/
  ci.yml
  deploy.yml
.devcontainer/devcontainer.json
Taskfile.yml
README.md
```

## Prerequisites

- Ubuntu host reachable via SSH (user with sudo)
- A domain (only required when enabling HTTPS)
- Ansible installed locally or use the provided GitHub Actions

## Quickstart

1. Create a vault password file (for CI you’ll set it as a secret):

```bash
printf '%s' 'YOUR_VAULT_PASSWORD' > .vaultpass
```

2. Set inventory host and SSH user in `ansible/inventories/production/hosts.ini` (or export `SSH_HOST`/`SSH_USER`).

3. Prepare secrets (one-time):

```bash
task prepare
```

4. HTTP-first install (fast start):

```bash
ansible-playbook -i ansible/inventories/production/hosts.ini ansible/playbooks/site.yml \
  --vault-password-file .vaultpass \
  -e enable_letsencrypt=false -e db_backend=local
```

5. Optional: Enable HTTPS now or later (idempotent):

```bash
ansible-playbook -i ansible/inventories/production/hosts.ini ansible/playbooks/site.yml \
  --vault-password-file .vaultpass \
  -e enable_letsencrypt=true -e domain="YOUR_DOMAIN" -e letsencrypt_email="YOU@example.com"
```

6. Visit `http(s)://YOUR_DOMAIN` to access Mautic. Admin user is created from `group_vars` on first run.

## Variables & Secrets

- `enable_letsencrypt` (bool): default `false`
- `domain`, `letsencrypt_email`: needed when TLS is enabled
- `db_backend`: `local` or `external`
- Local DB vars under `mautic.db.*` in `group_vars/all.yml`
- External DB vars: `db_host`, `db_port`, `db_name`, `db_user`; secret `db_password`
- Secrets: store in `ansible/group_vars/secrets.vault.yml` and encrypt with `ansible-vault`

## External DB migration (optional later)

1. Put Mautic in maintenance (UI) and stop crons
2. Dump current DB:

```bash
mysqldump -u root -p --single-transaction --routines --triggers mautic > mautic.sql
```

3. Create DB/user on external MariaDB and import the dump
4. Re-provision pointing to the external DB:

```bash
ansible-playbook -i ansible/inventories/production/hosts.ini ansible/playbooks/site.yml \
  --vault-password-file .vaultpass \
  -e db_backend=external -e db_host="DB_HOST" -e db_port=3306 -e db_name="mautic" -e db_user="mautic"
```

5. Verify login, segments, and campaigns; re-enable crons

## CI/CD

- `ci.yml` runs `ansible-lint` and `yamllint`
- `deploy.yml` provisions on pushes to `main`. Set repository secrets:
  - `SSH_HOST`, `SSH_USER`, `SSH_KEY`
  - `ANSIBLE_VAULT_PASSWORD`
  - `DOMAIN`, `EMAIL` (for TLS)

## Dev tooling

- Devcontainer installs Ansible + linters
- `Taskfile.yml` provides helpers:
  - `task lint` — run linters
  - `task ping` — Ansible ping
  - `task deploy:localdb` — provision with local DB
  - `task deploy:externaldb` — provision pointing to external DB
  - `task bl:provision` — create a BitLaunch server and write inventory
  - `task bl:destroy IP=1.2.3.4` — destroy a BitLaunch server by IP

## Optional: Provisioning via BitLaunch

If you prefer not to pre-provision a server, you can create one on BitLaunch:

1. Set `BITLAUNCH_API_KEY` in your environment or `.env` in repo root.
2. Optionally adjust `HOST_ID`, `HOST_IMAGE_ID`, `SIZE_ID`, `REGION_ID`, `SERVER_NAME`.
3. Run:

```bash
task bl:provision
```

This generates a temporary SSH keypair in `./tmp_ssh_keys/`, creates a server, and writes `ansible/inventories/production/hosts.ini` with `ansible_ssh_private_key_file` pointing to the key.

Destroying a server:

```bash
task bl:destroy IP=1.2.3.4
```

## Acceptance criteria

- Mautic login reachable over HTTP/HTTPS
- Admin user exists and works
- Idempotent re-runs (0 changes except renewals)
- Cron jobs present and logging to `/opt/mautic/logs/cron.log`

## License

MIT
