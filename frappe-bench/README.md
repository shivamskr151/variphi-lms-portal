# Frappe Bench - Learning Management System

This project is a Frappe Bench setup with Learning Management System (LMS) and Payments applications.

## Table of Contents

- [Quick Start](#quick-start)
- [Setup Instructions](#setup-instructions)
- [Database Configuration](#database-configuration)
- [Credentials](#credentials)
- [Fixes Applied](#fixes-applied)
- [Available Commands](#available-commands)
- [Applications](#applications)
- [Troubleshooting](#troubleshooting)
- [GitHub Setup](#github-setup)

## GitHub Setup

To upload this project to GitHub and maintain full control over your source code, see [GITHUB.md](GITHUB.md) for detailed instructions.

## Quick Start

1. **Stop any running processes:**
   ```bash
   ./bench-manage.sh stop
   ```

2. **Check everything is ready:**
   ```bash
   ./bench-manage.sh check
   ```

3. **Fix database (if needed):**
   ```bash
   mysql -u root -p < create_db_user.sql
   # OR
   sudo mysql < create_db_user.sql
   ```

4. **Start the project:**
   ```bash
   bench start
   ```

## Setup Instructions

### Complete Setup Steps

1. **Reset MariaDB Root Password** (if needed):
   ```bash
   sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '';"
   ```

2. **Create Database User:**
   ```bash
   cd frappe-bench
   mysql -u root < create_db_user.sql
   ```

3. **Start Bench (Terminal 1):**
   ```bash
   bench start
   ```
   Keep this running.

4. **Run Migrations (Terminal 2):**
   Open a new terminal and run:
   ```bash
   cd frappe-bench
   bench --site vgi.local migrate
   ```

5. **Access the Site:**
   - URL: http://vgi.local:8000 or http://127.0.0.1:8000
   - Username: Administrator
   - Password: admin

### All-in-One Setup Command

After resetting the password:
```bash
cd frappe-bench && \
mysql -u root < create_db_user.sql && \
bench --site vgi.local migrate && \
bench start
```

## Database Configuration

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
# Connect directly to the database
mysql -u _2ca05118bd4124f3 -pvAhQPAHJpRcIsQmi _2ca05118bd4124f3

# Or with host specification
mysql -u _2ca05118bd4124f3 -pvAhQPAHJpRcIsQmi -h localhost _2ca05118bd4124f3
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
Then copy and paste these SQL commands:
```sql
CREATE USER IF NOT EXISTS '_2ca05118bd4124f3'@'localhost' IDENTIFIED BY 'vAhQPAHJpRcIsQmi';
CREATE DATABASE IF NOT EXISTS `_2ca05118bd4124f3` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON `_2ca05118bd4124f3`.* TO '_2ca05118bd4124f3'@'localhost';
FLUSH PRIVILEGES;
```

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

## Credentials

### Database Credentials

**MariaDB Root:**
- Username: `root`
- Password: (empty - no password)
- Host: `localhost`
- Port: `3306`

**Site Database (vgi.local):**
- Database Name: `_2ca05118bd4124f3`
- Database User: `_2ca05118bd4124f3`
- Database Password: `vAhQPAHJpRcIsQmi`
- Host: `localhost`
- Port: `3306`

**Connection Strings:**
```bash
# MariaDB Root Connection (requires root password or sudo)
mysql -u root
# OR with sudo if root has no password
sudo mysql -u root

# Site Database Connection (Recommended)
mysql -u _2ca05118bd4124f3 -pvAhQPAHJpRcIsQmi _2ca05118bd4124f3

# Or use the convenient script
./access_database.sh
```

### Frappe Site Credentials

**Default Admin Login:**
- Site URL: `http://vgi.local:8000` or `http://127.0.0.1:8000`
- Username: `Administrator`
- Password: `admin` (default, may have been changed during setup)

**Reset Admin Password:**
```bash
bench --site vgi.local set-admin-password new_password
```

**Important Files:**
- Site Config: `sites/vgi.local/site_config.json`
- Database User SQL: `create_db_user.sql`
- Encryption Key: `EnBqYDlmOIPqGhwR7C-N90eR351VjSmoqu_WC0A6Gmc=`

**Security Note:**
⚠️ These credentials are for local development only! Do not use these in production. Change all passwords before deploying.

## Fixes Applied

### 1. esbuild Watch API Compatibility ✅
- **Issue**: esbuild 0.27.0 doesn't support `watch` option in `build()`
- **Fix**: Updated `apps/frappe/esbuild/esbuild.js` to use `esbuild.context()` API
- **Files Modified**: `apps/frappe/esbuild/esbuild.js`

### 2. Assets Directory Structure ✅
- **Issue**: Files existed where directories should be (`sites/assets/frappe/dist/js` was a file)
- **Fix**: Created script to clean and recreate proper directory structure
- **Files Created**: `fix_assets_directory.sh`
- **Action**: Run `./fix_assets_directory.sh` if issues recur

### 3. Missing highlight.js ✅
- **Issue**: highlight.js CSS file not found
- **Fix**: Installed highlight.js package
- **Command**: `cd apps/frappe && yarn add highlight.js`

### 4. Database User Setup ⚠️
- **Issue**: Database user `_2ca05118bd4124f3` doesn't exist
- **Fix**: Created SQL script
- **File**: `create_db_user.sql`
- **Action Required**: `mysql -u root -p < create_db_user.sql`

### Previous Fixes (Already Applied)
- ✅ Virtual environment permissions
- ✅ Windows path references (47+ files)
- ✅ Redis configuration files
- ✅ Procfile Node.js path
- ✅ Python executables

### Quick Fix Commands

```bash
# Fix environment (run once)
./bench-manage.sh fix-env

# Fix paths (regenerate Redis configs)
./bench-manage.sh fix-paths

# Fix UI assets (if needed)
./bench-manage.sh fix-ui

# Fix database (requires root password)
mysql -u root -p < create_db_user.sql

# Restart bench
./bench-manage.sh restart
```

## Available Commands

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

## Applications

### Frappe Framework

Frappe Framework is a full-stack web application framework that uses Python and MariaDB on the server side and a tightly integrated client side library.

**Key Features:**
- Full-Stack Framework
- Built-in Admin Interface
- Role-Based Permissions
- REST API
- Customizable Forms and Views
- Report Builder

**Development Setup:**
1. Setup bench by following the [Installation Steps](https://docs.frappe.io/framework/user/en/installation)
2. Start the server: `bench start`
3. Create a new site: `bench new-site frappe.localhost`
4. Open the URL `http://frappe.localhost:8000/app` in your browser

### Learning Management System (LMS)

**Easy to use, open source, Learning Management System**

**Key Features:**
- **Structured Learning**: Design a course with a 3-level hierarchy, where your courses have chapters and you can group your lessons within these chapters
- **Live Classes**: Group learners into batches based on courses and duration. Create Zoom live class for these batches right from the app
- **Quizzes and Assignments**: Create quizzes where questions can have single-choice, multiple-choice options, or can be open ended. Instructors can also add assignments which learners can submit as PDF's or Documents
- **Getting Certified**: Once a learner has completed the course or batch, you can grant them a certificate. The app provides an inbuilt certificate template

**Development Setup:**

1. Install bench and setup a `frappe-bench` directory by following the [Installation Steps](https://frappeframework.com/docs/user/en/installation)
2. Start the server by running `bench start`
3. In a separate terminal window, create a new site by running `bench new-site learning.test`
4. Map your site to localhost with the command `bench --site learning.test add-to-hosts`
5. Get the Learning app: `bench get-app https://github.com/frappe/lms`
6. Run `bench --site learning.test install-app lms`
7. Open the URL `http://learning.test:8000/lms` in your browser

**Docker Setup:**

1. Setup folder and download the required files:
   ```bash
   mkdir frappe-learning
   cd frappe-learning
   wget -O docker-compose.yml https://raw.githubusercontent.com/frappe/lms/develop/docker/docker-compose.yml
   wget -O init.sh https://raw.githubusercontent.com/frappe/lms/develop/docker/init.sh
   ```

2. Run the container and daemonize it:
   ```bash
   docker compose up -d
   ```

3. The site http://lms.localhost:8000/lms should now be available. Default credentials:
   - Username: Administrator
   - Password: admin

### Payments App

A payments app for frappe.

**Installation:**
1. Install [bench & frappe](https://frappeframework.com/docs/v14/user/en/installation)
2. Add the payments app to your bench:
   ```bash
   bench get-app payments
   ```
3. Install the payments app on the required site:
   ```bash
   bench --site <sitename> install-app payments
   ```

**App Structure:**
- App has 2 modules - Payments and Payment Gateways
- Payment Module contains the Payment Gateway DocType which creates links for the payment gateways
- Payment Gateways Module contains all the Payment Gateway (Razorpay, Stripe, Braintree, Paypal, PayTM) DocTypes
- App adds custom fields to Web Form for facilitating payments upon installation and removes them upon uninstallation

## Troubleshooting

### Common Issues

**Port Already in Use:**
If you see "Address already in use" errors:
```bash
./bench-manage.sh stop
```

**Database Connection Error:**
If you see "Access denied for user" error:
```bash
mysql -u root -p < create_db_user.sql
```

**Missing Dependencies:**
If you see module not found errors:
```bash
cd apps/frappe && yarn install
```

**Site vgi.local not found:**
Check which site exists:
```bash
ls sites/
bench --site <site_name> migrate
```

**Database connection failed:**
Verify user was created:
```bash
mysql -u root -e "SELECT User, Host FROM mysql.user WHERE User='_2ca05118bd4124f3';"
```

**Migration errors:**
Try:
```bash
bench --site vgi.local migrate --skip-search-index
```

### Verification

After starting, check:
- Web server: http://127.0.0.1:8000
- SocketIO: ws://0.0.0.0:9000
- Redis cache: port 13000
- Redis queue: port 11000

After fixes, verify:
- ✅ `bench start` starts all services
- ✅ Watch service works without esbuild errors
- ✅ Web server connects to database (after DB user creation)
- ✅ No file system errors in assets directory

## Resources

- [Frappe Framework Documentation](https://docs.frappe.io/framework)
- [LMS Documentation](https://docs.frappe.io/learning)
- [Frappe Cloud](https://frappecloud.com)
- [Discussion Forum](https://discuss.frappe.io/)

