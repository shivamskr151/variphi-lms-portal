# Docker Setup for LMS

This directory contains the Docker configuration for running the LMS application in a containerized environment.

## Overview

The Docker setup uses:
- **Official Frappe Bench image** from Docker Hub (`frappe/bench:latest`)
- **Complete source code** copied into the image during build
- **Volume mounts** for hot reload during development (local changes reflect immediately)

## Architecture

- **MariaDB 10.8**: Database service
- **Redis 7**: Cache and queue service  
- **Frappe Bench**: Application container with all apps and services

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB of available disk space
- Ports 8000, 9000, 5173, 3306, 6379 available

### Building and Running

**Option 1: Using the helper script (Recommended - automatically loads .env and checks Docker)**

```bash
cd frappe-bench/apps/lms/docker

# Build the Docker image
./docker-compose.sh build

# Start all services
./docker-compose.sh up -d

# View logs
./docker-compose.sh logs -f frappe

# Stop services
./docker-compose.sh down

# Stop and remove volumes (clean slate)
./docker-compose.sh down -v
```

**Option 2: Using docker-compose directly (requires Docker running and .env loaded)**

```bash
cd frappe-bench/apps/lms/docker

# Ensure Docker is running first
./docker-check.sh

# Load .env file (if not already loaded)
source ../../.env 2>/dev/null || true

# Build the Docker image
docker-compose build

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f frappe

# Stop services
docker-compose down
```

**Note:** The helper script (`docker-compose.sh`) automatically:
- Checks if Docker is running (starts it if needed on macOS)
- Loads environment variables from `.env` file
- Executes docker-compose commands with proper configuration

### Access the Application

- **Web UI**: http://localhost:8000
- **SocketIO**: ws://localhost:9000
- **Frontend Dev Server**: http://localhost:5173
- **MariaDB**: localhost:3307 (root password: `123`) - *Note: Uses port 3307 to avoid conflict with local MariaDB*
- **Redis**: localhost:6380 - *Note: Uses port 6380 to avoid conflict with local Redis*

**Note**: Port mappings are configured to avoid conflicts with local services. Container-to-container communication uses internal Docker networking and doesn't require these port mappings.

## Hot Reload / Development Mode

The docker-compose.yml is configured for development with volume mounts:

```yaml
volumes:
  - ../../../apps:/home/frappe/frappe-bench/apps:rw
  - ../../../sites:/home/frappe/frappe-bench/sites:rw
  - ../../../config:/home/frappe/frappe-bench/config:rw
  - ../../../logs:/home/frappe/frappe-bench/logs:rw
```

**Any changes you make to source code on your local machine will immediately reflect in the running container** without needing to rebuild the image.

### How It Works

1. Source code is **copied** into the image during build (for standalone/production use)
2. Source code is **mounted** as volumes during development (for hot reload)
3. Volume mounts **override** the copied files, so your local changes take precedence

## First Time Setup

On first run, the container will:
1. Wait for MariaDB to be ready
2. Verify bench structure exists
3. Create site `vgi.local` if it doesn't exist
4. Install LMS and Payments apps on the site
5. Build frontend assets
6. Start all bench services

Default site credentials:
- **Site**: `vgi.local`
- **Username**: `Administrator` (or admin)
- **Password**: `admin` (set via `ADMIN_PASSWORD` env var)

## Environment Variables

You can customize the setup using environment variables in docker-compose.yml:

```yaml
environment:
  - SITE_NAME=vgi.local           # Site name
  - ADMIN_PASSWORD=admin          # Admin password for new sites
  - MARIADB_HOST=mariadb          # Database host
  - MARIADB_ROOT_PASSWORD=123     # Database root password
```

## Production Deployment

For production, you can:

1. **Build a production image** without volume mounts:
   ```bash
   docker build -t lms-production -f apps/lms/docker/Dockerfile .
   ```

2. **Run without volume mounts** to use the copied source code:
   ```bash
   docker run -d \
     --name lms-prod \
     -p 8000:8000 \
     -p 9000:9000 \
     lms-production
   ```

3. **Use external databases** by setting environment variables

## Troubleshooting

### Container won't start
```bash
# Check logs
docker-compose logs frappe

# Check if MariaDB is ready
docker-compose logs mariadb
```

### Database connection issues
- Ensure MariaDB is healthy: `docker-compose ps`
- Check connection: `docker-compose exec mariadb mysql -u root -p123 -e "SELECT 1"`

### Permission issues
- The container runs as `frappe` user (UID 1000)
- Ensure mounted volumes have correct permissions

### Source code not updating
- Verify volume mounts in docker-compose.yml
- Check if volumes are actually mounted: `docker-compose exec frappe ls -la /home/frappe/frappe-bench/apps`

### Rebuild from scratch
```bash
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

## Files

- **Dockerfile**: Builds the application image with all source code
- **docker-compose.yml**: Orchestrates all services with volume mounts
- **docker-init.sh**: Initialization script that runs on container start
- **.dockerignore**: Excludes unnecessary files from build context

## Notes

- The build context is set to `frappe-bench/` directory (3 levels up from docker/)
- Source code is copied during build for portability
- Volume mounts enable hot reload in development
- Assets are built automatically on first run
- Bench services (web, socketio, worker, scheduler, watch) all run in the same container

