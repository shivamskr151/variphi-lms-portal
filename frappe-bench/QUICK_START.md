# Quick Start Guide

This guide will help you set up VariPhi LMS on any system quickly and without conflicts.

## Prerequisites

Before starting, ensure you have:
- **Python 3.10+** installed
- **Node.js 18+** and **Yarn** (or npm) installed
- **MariaDB 10.8+** or MySQL installed and running
- **Redis 7** installed and running (optional, can use local Redis instances)
- **Git** installed

## One-Command Setup

The easiest way to get started:

```bash
cd frappe-bench
./init-system.sh
```

This single command will:
1. ✅ Check all prerequisites
2. ✅ Create environment configuration (`.env`) with secure auto-generated credentials
3. ✅ Set up Python virtual environment
4. ✅ Install all Python dependencies
5. ✅ Install all Node.js dependencies
6. ✅ Generate all configuration files
7. ✅ Set up database user and database
8. ✅ Fix all paths and configurations
9. ✅ Build assets

## Step-by-Step Setup

If you prefer to understand each step:

### 1. Configure Environment

```bash
cd frappe-bench
./setup-env.sh
```

This will:
- Create `.env` file from `.env.example` if it doesn't exist
- Auto-generate secure database credentials
- Auto-generate encryption key
- Auto-detect your system username
- Generate all configuration files

**You can edit `.env` to customize:**
- Site name
- Database host/port
- Redis URLs
- Server ports
- Other settings

### 2. Install Dependencies

```bash
./setup-dependencies.sh
```

This installs all Python and Node.js dependencies.

### 3. Set Up Database

```bash
# The SQL file is auto-generated from your .env configuration
mysql -u root -p < create_db_user.sql
```

Or if root has no password:
```bash
mysql -u root < create_db_user.sql
# OR on some systems:
sudo mysql < create_db_user.sql
```

### 4. Start the Server

```bash
./bench-manage.sh start
```

### 5. Access the Application

Open your browser and go to:
- **URL**: http://127.0.0.1:8000 (or as configured in `.env`)
- **Username**: `Administrator`
- **Password**: `admin`

## Environment Configuration

The `.env` file contains all system-specific settings. Key variables:

```bash
# Site Configuration
SITE_NAME=vgi.local
SITE_HOST=http://127.0.0.1:8000

# Database (auto-generated if empty)
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=          # Auto-generated
DB_USER=          # Auto-generated
DB_PASSWORD=      # Auto-generated

# Redis
REDIS_CACHE=redis://127.0.0.1:13000
REDIS_QUEUE=redis://127.0.0.1:11000

# Server Ports
WEBSERVER_PORT=8000
SOCKETIO_PORT=9000
```

## Docker Setup

If you prefer Docker:

```bash
cd frappe-bench/apps/lms/docker
docker-compose up -d
```

See [docker/README.md](apps/lms/docker/README.md) for details.

## Troubleshooting

### Port Already in Use

If port 8000 is already in use, edit `.env`:
```bash
WEBSERVER_PORT=8001  # or any available port
./setup-env.sh      # Regenerate configs
```

### Database Connection Error

1. Check if MariaDB/MySQL is running:
   ```bash
   # macOS
   brew services list | grep mariadb
   
   # Linux
   sudo systemctl status mariadb
   ```

2. Verify database user exists:
   ```bash
   mysql -u root -e "SELECT User, Host FROM mysql.user WHERE User = 'YOUR_DB_USER';"
   ```

3. Recreate database user:
   ```bash
   mysql -u root -p < create_db_user.sql
   ```

### Redis Connection Error

If using local Redis instances, ensure they're running:
```bash
# Check if Redis is running on ports 13000 and 11000
redis-cli -p 13000 ping
redis-cli -p 11000 ping
```

Or update `.env` to use a single Redis instance:
```bash
REDIS_CACHE=redis://127.0.0.1:6379
REDIS_QUEUE=redis://127.0.0.1:6379
REDIS_SOCKETIO=redis://127.0.0.1:6379
./setup-env.sh
```

### Path Issues

If you move the project to a different location:
```bash
./bench-manage.sh fix-paths
```

### Virtual Environment Issues

```bash
./bench-manage.sh fix-env
```

## Common Commands

```bash
# Start server
./bench-manage.sh start

# Stop server
./bench-manage.sh stop

# Restart server
./bench-manage.sh restart

# Check system status
./bench-manage.sh check

# Update environment configs
./setup-env.sh

# Fix paths
./bench-manage.sh fix-paths

# Fix virtual environment
./bench-manage.sh fix-env
```

## Next Steps

After successful setup:

1. **Change default password**: Log in and change the Administrator password
2. **Configure site**: Set up your site name and domain
3. **Install apps**: Ensure all apps are installed
4. **Set up SSL**: For production, configure SSL certificates
5. **Backup strategy**: Set up regular database backups

## Getting Help

- Check [README.md](../README.md) for detailed documentation
- Review [frappe-bench/README.md](README.md) for bench-specific instructions
- See [DATABASE_CONNECTION_GUIDE.md](DATABASE_CONNECTION_GUIDE.md) for database help

