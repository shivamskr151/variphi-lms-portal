# VariPhi LMS - Learning Management System

A comprehensive, open-source Learning Management System built on the Frappe Framework. This project provides a complete solution for creating, managing, and delivering online courses with features like live classes, quizzes, assignments, and certifications.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Environment Configuration](#environment-configuration)
- [Database Setup](#database-setup)
- [Docker Setup](#docker-setup)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [GitHub Repository Management](#github-repository-management)
- [Project Structure](#project-structure)
- [Applications](#applications)
- [Security Notes](#security-notes)

---

## Overview

VariPhi LMS is a full-featured learning management system that enables educational institutions and organizations to create structured learning experiences. Built on Frappe Framework, it combines the power of Python backend with a modern Vue.js frontend.

### Features

- **📚 Structured Learning**: Design courses with a 3-level hierarchy (Courses → Chapters → Lessons)
- **🎥 Live Classes**: Group learners into batches and create Zoom live classes directly from the app
- **📝 Quizzes & Assignments**: Create quizzes with single-choice, multiple-choice, or open-ended questions. Instructors can add assignments for PDF/document submissions
- **🏆 Certifications**: Grant certificates upon course completion with built-in certificate templates
- **💳 Payment Integration**: Integrated payment gateway support via the Payments app (Razorpay, Stripe, Braintree, PayPal, PayTM)
- **👥 User Management**: Role-based access control with student, instructor, and admin roles
- **📊 Analytics & Reports**: Track signups, enrollments, and course completion statistics

## Tech Stack

- **Backend**: Python 3.10+ (Frappe Framework)
- **Frontend**: Vue.js, Frappe UI
- **Database**: MariaDB 10.8+
- **Cache/Queue**: Redis 7
- **Web Server**: Gunicorn
- **Real-time**: Socket.IO
- **Build Tools**: esbuild, Vite

## Prerequisites

- Python 3.10 or higher
- Node.js 18+ and Yarn
- MariaDB 10.8+
- Redis 7
- Git

---

## Quick Start

### Option 1: Automated Setup (Recommended for New Systems)

The easiest way to set up on a new system:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/shivamskr151/variphi-lms-portal.git
   cd variphi-lms-portal/frappe-bench
   ```

2. **Run the initialization script:**
   ```bash
   ./init-system.sh
   ```
   
   This script will:
   - Create `.env` file from `.env.example` with auto-generated secure credentials
   - Set up Python virtual environment
   - Install all dependencies (Python and Node.js)
   - Generate configuration files
   - Set up database (if MySQL/MariaDB is available)
   - Fix all paths and configurations

3. **Start the server:**
   ```bash
   ./bench-manage.sh start
   ```

4. **Access the application:**
   - URL: http://127.0.0.1:8000 (or as configured in `.env`)
   - Username: `Administrator`
   - Password: `admin`

**Note:** The `.env` file contains your system-specific configuration. It's automatically generated and excluded from git. You can edit it to customize settings.

### Option 2: Docker Setup (Recommended for Development)

The easiest way to get started is using Docker:

```bash
cd frappe-bench/apps/lms/docker

# Build and start all services
./docker-compose.sh build
./docker-compose.sh up -d

# View logs
./docker-compose.sh logs -f frappe
```

**Access Points:**
- Web UI: http://localhost:8000
- SocketIO: ws://localhost:9000
- Frontend Dev Server: http://localhost:5173
- MariaDB: localhost:3307 (root password: `123`)
- Redis: localhost:6380

**Default Credentials:**
- Site: `vgi.local`
- Username: `Administrator`
- Password: `admin`

### Option 3: Manual Setup (Advanced)

If you prefer manual setup or need to customize the process:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/shivamskr151/variphi-lms-portal.git
   cd variphi-lms-portal/frappe-bench
   ```

2. **Set up environment:**
   ```bash
   ./setup-env.sh
   # Edit .env file if needed
   ./setup-env.sh  # Run again to generate configs
   ```

3. **Set up database:**
   ```bash
   mysql -u root -p < create_db_user.sql
   ```

4. **Install dependencies:**
   ```bash
   ./setup-dependencies.sh
   ```

5. **Start the bench:**
   ```bash
   ./bench-manage.sh start
   ```

---

## Environment Configuration

This project uses a centralized `.env` file for all configuration. **No hardcoded values should exist in the codebase.**

### Quick Setup

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your values** (or let it auto-generate secure credentials)

3. **Generate configuration files:**
   ```bash
   ./setup-env.sh
   ```

### Environment Variables

All configuration is managed through the `.env` file. Here are the available variables:

#### Site Configuration
- `SITE_NAME` - Site name (default: `vgi.local`)
- `SITE_HOST` - Full site URL (default: `http://127.0.0.1:8000`)
- `APP_NAME` - Application name (default: `VariPhi`)

#### Database Configuration
- `DB_HOST` - Database host (default: `127.0.0.1`)
- `DB_PORT` - Database port (default: `3306`)
- `DB_TYPE` - Database type (default: `mariadb`)
- `DB_NAME` - Database name (auto-generated if empty)
- `DB_USER` - Database user (auto-generated if empty)
- `DB_PASSWORD` - Database password (auto-generated if empty)
- `MARIADB_ROOT_PASSWORD` - MariaDB root password (empty if no password)

#### Redis Configuration
- `REDIS_CACHE` - Redis cache URL (default: `redis://127.0.0.1:13000`)
- `REDIS_QUEUE` - Redis queue URL (default: `redis://127.0.0.1:11000`)
- `REDIS_SOCKETIO` - Redis SocketIO URL (default: `redis://127.0.0.1:11000`)

#### Server Configuration
- `WEBSERVER_PORT` - Web server port (default: `8000`)
- `SOCKETIO_PORT` - SocketIO port (default: `9000`)
- `FILE_WATCHER_PORT` - File watcher port (default: `6787`)
- `GUNICORN_WORKERS` - Number of Gunicorn workers (default: `9`)
- `BACKGROUND_WORKERS` - Number of background workers (default: `1`)

#### User Configuration
- `FRAPPE_USER` - Frappe user (auto-detected from system if empty)

#### Development Settings
- `DEVELOPER_MODE` - Enable developer mode (default: `1`)
- `LIVE_RELOAD` - Enable live reload (default: `true`)
- `SERVE_DEFAULT_SITE` - Serve default site (default: `true`)

#### Security
- `ENCRYPTION_KEY` - Encryption key (auto-generated if empty)

#### Docker Configuration
- `DOCKER_MODE` - Set to `true` if running in Docker (default: `false`)

### Auto-Generated Files

The following files are **auto-generated** from `.env` and should **not be edited manually**:

- `sites/common_site_config.json` - Frappe common configuration
- `sites/*/site_config.json` - Site-specific configuration
- `create_db_user.sql` - Database setup SQL script

To regenerate these files, run:
```bash
./setup-env.sh
```

### Loading Environment Variables in Scripts

All scripts should load the `.env` file at the beginning. Use one of these methods:

**Method 1: Direct loading (recommended)**
```bash
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$BENCH_DIR/.env" ]; then
    set -a
    source "$BENCH_DIR/.env"
    set +a
fi
```

**Method 2: Using the helper script**
```bash
source "$(dirname "${BASH_SOURCE[0]}")/load-env.sh"
```

### Security Notes

⚠️ **Important:**
- Never commit `.env` to version control (it's in `.gitignore`)
- Never commit `create_db_user.sql` (contains credentials)
- Never commit `sites/*/site_config.json` (contains sensitive data)
- Never commit `sites/common_site_config.json` (contains system config)

All sensitive files are automatically excluded from git.

---

## Database Setup

### Database Connection Details

**Site:** `vgi.local`

**Local Development:**
- **Host**: `127.0.0.1`
- **Port**: `3306`
- **Database**: Auto-generated from `.env` (check `create_db_user.sql` or `sites/vgi.local/site_config.json`)
- **Username**: Auto-generated from `.env`
- **Password**: Auto-generated from `.env`

**Connection String:**
```
mysql://DB_USER:DB_PASSWORD@127.0.0.1:3306/DB_NAME
```

**MariaDB Root Access:**
- **Host**: `127.0.0.1` or `localhost`
- **Port**: `3306`
- **Username**: `root`
- **Password**: (empty - no password) or check your MariaDB configuration

### Quick Database Access

**Easiest Way - Use the access script:**
```bash
cd frappe-bench
./access_database.sh                    # Open interactive MySQL shell
./access_database.sh info               # Show database information
./access_database.sh tables             # List all tables
./access_database.sh status             # Check database status
./access_database.sh backup             # Create a backup
./access_database.sh "SHOW TABLES;"     # Run SQL commands
```

**Using Bench Commands (Recommended):**
```bash
# Open MariaDB console (auto-connects to site database)
bench --site vgi.local mariadb

# Open Python console with database access
bench --site vgi.local console

# Open database console
bench --site vgi.local db-console
```

**Direct MySQL Connection:**
```bash
# Connect directly to the database (credentials from .env)
mysql -h 127.0.0.1 -P 3306 -u DB_USER -pDB_PASSWORD DB_NAME

# Or with host specification
mysql -h 127.0.0.1 -P 3306 -u DB_USER -pDB_PASSWORD -h localhost DB_NAME
```

### Database User Setup

If the database user doesn't exist, create it:

**Option A - If you know the root password:**
```bash
cd frappe-bench
mysql -u root -p < create_db_user.sql
```
(Enter your MariaDB root password when prompted)

**Option B - If root has no password:**
```bash
cd frappe-bench
mysql -u root < create_db_user.sql
```

**Option C - Using sudo:**
```bash
cd frappe-bench
sudo mysql < create_db_user.sql
```

**Option D - Interactive session:**
```bash
mysql -u root -p
```
Then copy and paste the SQL commands from `create_db_user.sql`.

### Reset MariaDB Root Password

**Quick Method:**
```bash
# Reset to empty password (no password)
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '';"

# OR set a new password
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'your_new_password';"
```

**If Quick Method Doesn't Work:**

1. Stop MariaDB:
   ```bash
   brew services stop mariadb
   ```

2. Start MariaDB in Safe Mode (in a new terminal):
   ```bash
   sudo mysqld_safe --skip-grant-tables --skip-networking &
   ```

3. Connect Without Password:
   ```bash
   mysql -u root
   ```

4. Reset Password:
   ```sql
   FLUSH PRIVILEGES;
   ALTER USER 'root'@'localhost' IDENTIFIED BY 'your_new_password';
   FLUSH PRIVILEGES;
   EXIT;
   ```

5. Stop Safe Mode and Restart MariaDB:
   ```bash
   sudo pkill mysqld
   brew services start mariadb
   ```

### GUI Database Tools

#### TablePlus (Recommended for macOS)
```bash
brew install --cask tableplus
```
Connect using:
- **Host**: `127.0.0.1`
- **Port**: `3306`
- **User**: From `.env` or `site_config.json`
- **Password**: From `.env` or `site_config.json`
- **Database**: From `.env` or `site_config.json`

#### MySQL Workbench
```bash
brew install --cask mysql-workbench
```

#### DBeaver
```bash
brew install --cask dbeaver-community
```

---

## Docker Setup

The Docker setup supports hot-reload for development:
- Source code is mounted as volumes
- Changes reflect immediately without rebuild
- All services run in containers
- Ports are mapped to avoid conflicts with local services

### Prerequisites

1. **Docker Desktop installed and running**
   - Check: `docker info` should work without errors
   - If not running: `open -a Docker` (macOS) or start Docker Desktop manually

2. **Environment configured**
   - `.env` file exists in `frappe-bench/` directory
   - Run `./setup-env.sh` if needed

### Quick Commands

**Using Helper Script (Recommended)**

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

**Using docker-compose directly:**
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

### Access Points

Once running, access:
- **Web UI**: http://localhost:8000
- **SocketIO**: ws://localhost:9000
- **Frontend Dev Server**: http://localhost:5173
- **Docker MariaDB**: localhost:3307
- **Docker Redis**: localhost:6380

### Shared Database Setup

Docker is configured to connect to your **local MariaDB database** instead of using a separate Docker MariaDB container. This means both environments share the same data.

**How It Works:**
- **Local Development**: Connects to `127.0.0.1:3306` (local MariaDB)
- **Docker**: Connects to `host.docker.internal:3306` (local MariaDB from container)

Both environments use the same database, so data created locally will appear in Docker and vice versa.

**Requirements:**
1. Local MariaDB must be running on port 3306
2. MariaDB must allow connections from Docker containers (usually enabled by default on macOS/Windows)

**Switching Between Local and Docker:**
- **Local → Docker**: The `restore-local-config.sh` script automatically updates the site config
- **Docker → Local**: Run `./bench-manage.sh start` which automatically fixes the database port

### Docker Troubleshooting

#### "Cannot connect to the Docker daemon"
**On macOS:**
```bash
open -a Docker
# Wait 30-60 seconds for Docker to fully start
```

**Quick fix using helper script:**
```bash
cd frappe-bench/apps/lms/docker
./docker-check.sh
```

#### Port Already in Use
```bash
# Check what's using ports
lsof -i :8000
lsof -i :3307
```

#### Container Keeps Restarting
```bash
# Check container logs
docker-compose logs frappe
docker-compose logs mariadb
docker-compose logs redis
```

#### Environment Variables Not Loading
Use the helper script (automatically loads .env):
```bash
./docker-compose.sh build
./docker-compose.sh up
```

#### Slow Performance
1. Increase Docker Desktop resources:
   - Docker Desktop → Settings → Resources
   - Increase CPU and Memory allocation

2. Check resource usage:
   ```bash
   docker stats
   ```

---

## Development

### Using Bench Management Script

The project includes a convenient management script for common operations:

```bash
cd frappe-bench

# Stop all services
./bench-manage.sh stop

# Check system status
./bench-manage.sh check

# Start services
./bench-manage.sh start

# Restart services
./bench-manage.sh restart

# Fix common issues
./bench-manage.sh fix-env
./bench-manage.sh fix-ui
./bench-manage.sh fix-paths
```

### Frontend Development

```bash
cd frappe-bench/apps/lms

# Install dependencies
yarn install

# Start development server
yarn dev

# Build for production
yarn build
```

### Backend Development

```bash
cd frappe-bench

# Activate virtual environment
source env/bin/activate

# Run migrations
bench --site vgi.local migrate

# Open Python console
bench --site vgi.local console

# Open database console
bench --site vgi.local mariadb
```

### Available Commands

Use the consolidated `bench-manage.sh` script for all operations:

- `./bench-manage.sh stop` - Stop all bench processes
- `./bench-manage.sh check` - Check all components and show what needs fixing
- `./bench-manage.sh fix-env` - Fix environment and path issues
- `./bench-manage.sh fix-ui` - Fix UI assets
- `./bench-manage.sh fix-login` - Fix login issues
- `./bench-manage.sh fix-paths` - Make all paths dynamic
- `./bench-manage.sh start` - Start bench
- `./bench-manage.sh restart` - Restart bench
- `./bench-manage.sh status` - Check bench status
- `./bench-manage.sh verify-ui` - Verify UI is working

Run `./bench-manage.sh help` for full command list.

---

## Troubleshooting

### Port Already in Use
```bash
./bench-manage.sh stop
```

### Database Connection Error

**Create/Reset Database User:**
```bash
cd frappe-bench
mysql -u root < create_db_user.sql
# OR if root has password
mysql -u root -p < create_db_user.sql
```

**Check Database Connection:**
```bash
# Use credentials from .env or site_config.json
mysql -h 127.0.0.1 -P 3306 -u DB_USER -pDB_PASSWORD DB_NAME -e "SELECT 1"
```

**Check if MariaDB is Running:**
```bash
brew services list | grep mariadb
# Start if not running
brew services start mariadb
```

**Verify Database User Exists:**
```bash
mysql -u root -e "SELECT User, Host FROM mysql.user WHERE User = 'DB_USER';"
```

### Missing Dependencies
```bash
cd frappe-bench/apps/frappe && yarn install
cd frappe-bench/apps/lms && yarn install
```

### Migration Errors
```bash
bench --site vgi.local migrate --skip-search-index
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

### Site vgi.local not found
Check which site exists:
```bash
ls sites/
bench --site <site_name> migrate
```

---

## GitHub Repository Management

### Uploading to GitHub

1. **Create a GitHub Repository:**
   - Go to GitHub and create a new repository
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)

2. **Connect Local Repository to GitHub:**
   ```bash
   cd frappe-bench
   
   # Add the remote repository (replace YOUR_USERNAME and REPO_NAME)
   git remote add origin https://github.com/YOUR_USERNAME/REPO_NAME.git
   
   # Rename branch to main (if needed)
   git branch -M main
   
   # Push your code
   git push -u origin main
   ```

### Maintaining Control Over Your Code

⚠️ **Important: Preventing Automatic Updates**

To ensure Frappe or Bench updates don't automatically affect your code:

**Never Run These Commands:**
```bash
# ❌ DO NOT RUN - These will pull updates from Frappe/Bench repositories
bench update
bench update --pull
bench get-app frappe --branch develop
bench get-app lms --branch develop
```

**Safe Commands (These are OK):**
```bash
# ✅ Safe - These only affect your local environment
bench start
bench --site <site> migrate
bench --site <site> console
bench build
```

### Repository Management Best Practices

1. **Regular Commits:**
   ```bash
   git add .
   git commit -m "Description of your changes"
   git push
   ```

2. **Branch Strategy:**
   ```bash
   git checkout -b feature/new-feature
   # Make changes
   git add .
   git commit -m "Add new feature"
   git push -u origin feature/new-feature
   ```

3. **Review Changes Before Committing:**
   ```bash
   git status          # See what changed
   git diff            # See detailed changes
   git add -p          # Interactively stage changes
   ```

4. **Protect Sensitive Data:**
   - Never commit passwords or API keys
   - Never commit database dumps with real data
   - Never commit personal information
   - The `.gitignore` file is configured to exclude sensitive files

---

## Project Structure

```
variphi-lms-portal/
├── frappe-bench/              # Main Frappe Bench directory
│   ├── apps/                  # Frappe applications
│   │   ├── frappe/           # Frappe Framework core
│   │   ├── lms/              # Learning Management System app
│   │   └── payments/         # Payment gateway integrations
│   ├── sites/                 # Site configurations and data
│   │   └── vgi.local/        # Default site
│   ├── config/                # Configuration files
│   ├── logs/                  # Application logs
│   ├── env/                   # Python virtual environment
│   ├── Procfile              # Process definitions
│   ├── .env                   # Environment configuration (auto-generated)
│   ├── .env.example           # Environment template
│   ├── setup-env.sh           # Environment setup script
│   ├── init-system.sh         # Complete system initialization
│   ├── bench-manage.sh        # Bench management script
│   └── access_database.sh     # Database access helper
└── README.md                  # This file
```

---

## Applications

### Frappe Framework

The core framework providing:
- Full-stack web application framework
- Built-in admin interface
- Role-based permissions
- REST API
- Customizable forms and views
- Report builder

### LMS (Learning Management System)

**Features:**
- Course creation and management
- Chapter and lesson organization
- Batch management for live classes
- Quiz and assignment system
- Certificate generation
- Student enrollment tracking
- Progress monitoring

**Development Setup:**
1. Install bench and setup a `frappe-bench` directory
2. Start the server by running `bench start`
3. Create a new site: `bench new-site learning.test`
4. Map your site to localhost: `bench --site learning.test add-to-hosts`
5. Get the Learning app: `bench get-app https://github.com/frappe/lms`
6. Run `bench --site learning.test install-app lms`
7. Open the URL `http://learning.test:8000/lms` in your browser

### Payments App

Payment gateway integration supporting:
- Razorpay
- Stripe
- Braintree
- PayPal
- PayTM

**Installation:**
1. Install bench & frappe
2. Add the payments app to your bench: `bench get-app payments`
3. Install the payments app on the required site: `bench --site <sitename> install-app payments`

---

## Security Notes

⚠️ **Important Security Information:**

1. **These credentials are for LOCAL DEVELOPMENT ONLY**
2. **Never commit these credentials to version control**
3. **Change all passwords before deploying to production**
4. **The database user has full access to the site database**

### Default Credentials

**Site Access:**
- URL: http://vgi.local:8000 or http://127.0.0.1:8000
- Username: `Administrator`
- Password: `admin` (default, may have been changed during setup)

**Reset Admin Password:**
```bash
bench --site vgi.local set-admin-password new_password
```

**Important Files:**
- Site Config: `sites/vgi.local/site_config.json`
- Database User SQL: `create_db_user.sql`
- Encryption Key: Check `site_config.json`

---

## Fixes Applied

### 1. esbuild Watch API Compatibility ✅
- **Issue**: esbuild 0.27.0 doesn't support `watch` option in `build()`
- **Fix**: Updated `apps/frappe/esbuild/esbuild.js` to use `esbuild.context()` API

### 2. Assets Directory Structure ✅
- **Issue**: Files existed where directories should be
- **Fix**: Created script to clean and recreate proper directory structure

### 3. Missing highlight.js ✅
- **Issue**: highlight.js CSS file not found
- **Fix**: Installed highlight.js package

### 4. Redis Queue Port Mismatch ✅
- **Issue**: Redis queue was starting on port 6379 instead of port 11000
- **Fix**: Enhanced Redis configuration and bench-manage.sh to enforce correct port

### 5. esbuild Platform Mismatch ✅
- **Issue**: esbuild had Linux ARM64 binaries but system needs macOS ARM64 binaries
- **Fix**: Reinstalled with correct platform binaries

### 6. Hardcoded Configuration Values ✅
- **Issue**: Configuration files contained hardcoded values specific to one system
- **Fix**: All values now stored in `.env` file with auto-generation support

### 7. Database User Setup ⚠️
- **Issue**: Database user may not exist
- **Fix**: Created SQL script (`create_db_user.sql`) - run `mysql -u root -p < create_db_user.sql`

---

## Configuration Philosophy

### No Hardcoded Values Policy

✅ **All hardcoded values have been removed from executable code**
✅ **All configuration comes from `.env` file**
✅ **All scripts use environment variables**
✅ **Auto-generation ensures no manual configuration needed**
✅ **System-specific files are excluded from git**

The codebase is now **fully portable** and can run on any system without conflicts!

### Auto-Generated Files

These files are **auto-generated** and should **not be edited manually**:
- `sites/common_site_config.json` - Generated from `.env`
- `sites/*/site_config.json` - Generated from `.env`
- `create_db_user.sql` - Generated from `.env`
- `config/redis_*.conf` - Generated dynamically

### Files Excluded from Git

These files contain system-specific or sensitive data and are excluded:
- `.env` - Contains all configuration
- `create_db_user.sql` - Contains database credentials
- `sites/*/site_config.json` - Contains site-specific config
- `sites/common_site_config.json` - Contains system config

---

## Resources

- [Frappe Framework Documentation](https://docs.frappe.io/framework)
- [LMS Documentation](https://docs.frappe.io/learning)
- [Frappe Cloud](https://frappecloud.com)
- [Discussion Forum](https://discuss.frappe.io/)

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the AGPL-3.0 License. See individual app licenses:
- [Frappe License](frappe-bench/apps/frappe/LICENSE)
- [LMS License](frappe-bench/apps/lms/license.txt)
- [Payments License](frappe-bench/apps/payments/license.txt)

## Links

- **Repository**: https://github.com/shivamskr151/variphi-lms-portal
- **Issues**: https://github.com/shivamskr151/variphi-lms-portal/issues
- **Frappe Framework**: https://frappeframework.com
- **LMS App**: https://github.com/frappe/lms

## Support

For support and questions:
- Check the [Frappe Discussion Forum](https://discuss.frappe.io/)
- Review the [documentation](https://docs.frappe.io/)
- Open an issue on GitHub

## Acknowledgments

- Built on [Frappe Framework](https://frappeframework.com)
- LMS app by [Frappe Technologies](https://frappe.io)
- Payment integrations via Frappe Payments app

---

**Note**: This is a development setup. For production deployment, ensure you:
- Change all default passwords
- Configure proper security settings
- Set up SSL/TLS certificates
- Configure backup strategies
- Review and harden database security
- Set up monitoring and logging
