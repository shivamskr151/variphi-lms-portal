# Docker Quick Start Guide

## Prerequisites

1. **Docker Desktop installed and running**
   - Check: `docker info` should work without errors
   - If not running: `open -a Docker` (macOS) or start Docker Desktop manually

2. **Environment configured**
   - `.env` file exists in `frappe-bench/` directory
   - Run `./setup-env.sh` if needed

## Quick Commands

### Using Helper Script (Recommended)

The helper script automatically:
- ✅ Checks if Docker is running (starts it if needed)
- ✅ Loads `.env` file
- ✅ Executes docker-compose commands

```bash
cd frappe-bench/apps/lms/docker

# Build images
./docker-compose.sh build

# Start all services
./docker-compose.sh up -d

# View logs
./docker-compose.sh logs -f frappe

# Stop services
./docker-compose.sh down

# Stop and remove everything (clean slate)
./docker-compose.sh down -v
```

### Using docker-compose directly

```bash
cd frappe-bench/apps/lms/docker

# Ensure Docker is running
./docker-check.sh

# Load environment variables
source ../../../.env

# Build and start
docker-compose build
docker-compose up -d
```

## Common Workflows

### First Time Setup

```bash
cd frappe-bench/apps/lms/docker

# 1. Check Docker is running
./docker-check.sh

# 2. Build images (first time takes 10-15 minutes)
./docker-compose.sh build

# 3. Start services
./docker-compose.sh up -d

# 4. Watch logs
./docker-compose.sh logs -f frappe
```

### Daily Development

```bash
cd frappe-bench/apps/lms/docker

# Start services
./docker-compose.sh up -d

# View logs
./docker-compose.sh logs -f frappe

# Stop when done
./docker-compose.sh down
```

### Reset Everything

```bash
cd frappe-bench/apps/lms/docker

# Stop and remove everything
./docker-compose.sh down -v

# Rebuild from scratch
./docker-compose.sh build
./docker-compose.sh up -d
```

## Access Points

Once running, access:

- **Web UI**: http://localhost:8000
- **SocketIO**: ws://localhost:9000
- **Frontend Dev Server**: http://localhost:5173
- **Docker MariaDB**: localhost:3307
- **Docker Redis**: localhost:6380

## Troubleshooting

If you encounter issues:

1. **Docker not running?**
   ```bash
   ./docker-check.sh
   ```

2. **Port conflicts?**
   ```bash
   # Check what's using ports
   lsof -i :8000
   lsof -i :3307
   ```

3. **Need to see logs?**
   ```bash
   ./docker-compose.sh logs -f
   ```

4. **Still having issues?**
   - See `DOCKER_TROUBLESHOOTING.md` for detailed help
   - Check `README.md` for full documentation

## Environment Variables

All configuration comes from `.env` file in `frappe-bench/`:

- `MARIADB_ROOT_PASSWORD` - Database root password
- `REDIS_CACHE`, `REDIS_QUEUE`, `REDIS_SOCKETIO` - Redis URLs
- `SITE_NAME` - Site name (default: vgi.local)
- `DB_HOST`, `DB_PORT` - Database connection

See `../../../ENV_SETUP.md` for complete list.

