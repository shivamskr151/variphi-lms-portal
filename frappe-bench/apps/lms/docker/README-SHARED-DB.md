# Shared Database Configuration

This Docker setup is configured to use the **local MariaDB database** instead of a separate Docker MariaDB container. This allows both local and Docker environments to share the same data.

## How It Works

- **Local Development**: Connects to `127.0.0.1:3306` (local MariaDB)
- **Docker**: Connects to `host.docker.internal:3306` (local MariaDB from container)

Both environments use the same database, so data created locally will appear in Docker and vice versa.

## Requirements

1. **Local MariaDB must be running** on port 3306
2. **MariaDB must allow connections from Docker containers** (usually enabled by default on macOS/Windows)

## Switching Between Local and Docker

When switching between local and Docker:

1. **Local → Docker**: 
   - The `restore-local-config.sh` script automatically updates the site config
   - Docker will use `host.docker.internal:3306` to connect to local MariaDB

2. **Docker → Local**:
   - Run `./bench-manage.sh start` which automatically fixes the database port
   - Local will use `127.0.0.1:3306`

## Using Separate Docker Database (Optional)

If you want Docker to use a separate database instead:

1. Set environment variable: `MARIADB_HOST=mariadb`
2. The Docker MariaDB container will be used instead
3. Data will NOT be shared between local and Docker

## Troubleshooting

If Docker can't connect to local MariaDB:

1. Ensure MariaDB is running: `brew services list | grep mariadb`
2. Check MariaDB is listening on port 3306: `lsof -i :3306`
3. On Linux, you may need to use `172.17.0.1` instead of `host.docker.internal`

