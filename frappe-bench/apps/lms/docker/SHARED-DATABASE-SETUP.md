# Shared Database Setup - Local and Docker

## Problem
When you create a course locally, it doesn't show up in Docker because they use **separate databases**.

## Solution
Docker is now configured to connect to your **local MariaDB database** instead of using a separate Docker MariaDB container. This means both environments share the same data.

## How It Works

### Local Development
- Connects to: `127.0.0.1:3306` (local MariaDB)
- Database: `_517a1fbab7ba0c04`
- Site config: `sites/vgi.local/site_config.json`

### Docker
- Connects to: `host.docker.internal:3306` (local MariaDB from container)
- Same database: `_517a1fbab7ba0c04`
- Site config: Automatically updated by `docker-init.sh`

## Setup Instructions

### 1. Ensure Local MariaDB is Running
```bash
brew services start mariadb
# Or check if running:
brew services list | grep mariadb
```

### 2. Verify MariaDB is Accessible
```bash
mysql -h 127.0.0.1 -P 3306 -u root -e "SELECT 1"
```

### 3. Start Docker
```bash
cd frappe-bench/apps/lms/docker
docker-compose up -d
```

The `docker-init.sh` script will automatically:
- Update site config to use `host.docker.internal:3306`
- Connect to your local MariaDB database
- Use the same data as local development

## Switching Between Environments

### Local → Docker
1. Stop local bench: `./bench-manage.sh stop`
2. Start Docker: `cd apps/lms/docker && docker-compose up -d`
3. Site config is automatically updated to use `host.docker.internal`

### Docker → Local
1. Stop Docker: `cd apps/lms/docker && docker-compose down`
2. Start local bench: `./bench-manage.sh start`
3. Site config is automatically updated to use `127.0.0.1:3306`

## Troubleshooting

### Docker Can't Connect to Local MariaDB

**On macOS/Windows:**
- `host.docker.internal` should work automatically
- Check: `ping host.docker.internal` from inside container

**On Linux:**
- Use the host's IP address instead
- Find IP: `ip addr show docker0 | grep inet`
- Or use: `172.17.0.1` (default Docker bridge gateway)

### MariaDB Connection Refused

1. Check MariaDB is running:
   ```bash
   brew services list | grep mariadb
   ```

2. Check MariaDB is listening on port 3306:
   ```bash
   lsof -i :3306
   ```

3. Verify MariaDB allows TCP connections (not just socket):
   - Check `/opt/homebrew/etc/my.cnf` or `/usr/local/etc/my.cnf`
   - Ensure `bind-address = 0.0.0.0` or `bind-address = 127.0.0.1`

### Using Separate Docker Database (Optional)

If you want Docker to use a separate database:

1. Set environment variable:
   ```bash
   export MARIADB_HOST=mariadb
   cd apps/lms/docker
   docker-compose up -d
   ```

2. This will use the Docker MariaDB container instead
3. Data will NOT be shared between local and Docker

## Benefits

✅ **Same Data**: Courses created locally appear in Docker  
✅ **No Duplication**: Single source of truth  
✅ **Easy Switching**: Switch between local and Docker seamlessly  
✅ **Development Friendly**: Test in both environments with same data

## Notes

- The `sites` directory is mounted, so file uploads are also shared
- Redis is still separate (Docker uses its own Redis container)
- Cache may differ between environments (clear cache if needed)

