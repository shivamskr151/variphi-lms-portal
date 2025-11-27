# Environment Configuration Guide

This project uses a centralized `.env` file for all configuration. **No hardcoded values should exist in the codebase.**

## Quick Start

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your values** (or let it auto-generate secure credentials)

3. **Generate configuration files:**
   ```bash
   ./setup-env.sh
   ```

## Environment Variables

All configuration is managed through the `.env` file. Here are the available variables:

### Site Configuration
- `SITE_NAME` - Site name (default: `vgi.local`)
- `SITE_HOST` - Full site URL (default: `http://127.0.0.1:8000`)
- `APP_NAME` - Application name (default: `VariPhi`)

### Database Configuration
- `DB_HOST` - Database host (default: `127.0.0.1`)
- `DB_PORT` - Database port (default: `3306`)
- `DB_TYPE` - Database type (default: `mariadb`)
- `DB_NAME` - Database name (auto-generated if empty)
- `DB_USER` - Database user (auto-generated if empty)
- `DB_PASSWORD` - Database password (auto-generated if empty)
- `MARIADB_ROOT_PASSWORD` - MariaDB root password (empty if no password)

### Redis Configuration
- `REDIS_CACHE` - Redis cache URL (default: `redis://127.0.0.1:13000`)
- `REDIS_QUEUE` - Redis queue URL (default: `redis://127.0.0.1:11000`)
- `REDIS_SOCKETIO` - Redis SocketIO URL (default: `redis://127.0.0.1:11000`)

### Server Configuration
- `WEBSERVER_PORT` - Web server port (default: `8000`)
- `SOCKETIO_PORT` - SocketIO port (default: `9000`)
- `FILE_WATCHER_PORT` - File watcher port (default: `6787`)
- `GUNICORN_WORKERS` - Number of Gunicorn workers (default: `9`)
- `BACKGROUND_WORKERS` - Number of background workers (default: `1`)

### User Configuration
- `FRAPPE_USER` - Frappe user (auto-detected from system if empty)

### Development Settings
- `DEVELOPER_MODE` - Enable developer mode (default: `1`)
- `LIVE_RELOAD` - Enable live reload (default: `true`)
- `SERVE_DEFAULT_SITE` - Serve default site (default: `true`)

### Security
- `ENCRYPTION_KEY` - Encryption key (auto-generated if empty)

### Docker Configuration
- `DOCKER_MODE` - Set to `true` if running in Docker (default: `false`)

## Auto-Generated Files

The following files are **auto-generated** from `.env` and should **not be edited manually**:

- `sites/common_site_config.json` - Frappe common configuration
- `sites/*/site_config.json` - Site-specific configuration
- `create_db_user.sql` - Database setup SQL script

To regenerate these files, run:
```bash
./setup-env.sh
```

## Loading Environment Variables in Scripts

All scripts should load the `.env` file at the beginning. Use one of these methods:

### Method 1: Direct loading (recommended)
```bash
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$BENCH_DIR/.env" ]; then
    set -a
    source "$BENCH_DIR/.env"
    set +a
fi
```

### Method 2: Using the helper script
```bash
source "$(dirname "${BASH_SOURCE[0]}")/load-env.sh"
```

## Docker Configuration

When using Docker, environment variables from `.env` are automatically loaded by `docker-compose.yml`. The Docker setup will:

1. Use `REDIS_CACHE`, `REDIS_QUEUE`, `REDIS_SOCKETIO` from `.env` (or defaults to `redis://redis:6379`)
2. Use `MARIADB_ROOT_PASSWORD` from `.env` (or defaults to empty)
3. Use `DB_HOST` from `.env` (or defaults to `host.docker.internal`)

## Verification

To verify that no hardcoded values exist:

```bash
# Check for hardcoded site names (excluding docs)
grep -r "vgi.local" --exclude-dir=node_modules --exclude-dir=.git --exclude="*.md" --exclude="*.txt" .

# Check for hardcoded database credentials
grep -r "_2ca05118bd4124f3\|vAhQPAHJpRcIsQmi\|_517a1fbab7ba0c04\|yIawHBFVcaiAKaJw" --exclude-dir=node_modules --exclude-dir=.git --exclude="*.md" --exclude="*.txt" .
```

## Files Updated

The following files have been updated to use `.env`:

- ✅ `open_database.sh` - Reads DB credentials from `.env`/`site_config.json`
- ✅ `restore-local-config.sh` - Reads Redis URLs from `.env`
- ✅ `docker-compose.yml` - Uses environment variables
- ✅ `Dockerfile` - Uses build args for configuration
- ✅ `docker-init.sh` - Uses environment variables for Redis
- ✅ `setup-env.sh` - Generates configs from `.env`
- ✅ `bench-manage.sh` - Loads from `.env`
- ✅ `access_database.sh` - Loads from `.env`
- ✅ `fix-ui.sh` - Loads from `.env`
- ✅ `bootstrap_db.py` - Uses `SITE_NAME` from environment
- ✅ `fix_database.py` - Uses `SITE_NAME` from environment
- ✅ `auto_reinstall.exp` - Reads `SITE_NAME` from `.env`

## Security Notes

⚠️ **Important:**
- Never commit `.env` to version control (it's in `.gitignore`)
- Never commit `create_db_user.sql` (contains credentials)
- Never commit `sites/*/site_config.json` (contains sensitive data)
- Never commit `sites/common_site_config.json` (contains system config)

All sensitive files are automatically excluded from git.

