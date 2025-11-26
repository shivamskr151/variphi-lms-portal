# Database Connection Guide

Complete guide for connecting to the VariPhi LMS database.

## 📊 Current Database Information

### Site: `vgi.local`

**Connection Details:**
- **Database Type**: MariaDB/MySQL
- **Host**: `127.0.0.1` (Local) or `host.docker.internal` (Docker)
- **Port**: `3306`
- **Database Name**: `_517a1fbab7ba0c04`
- **Username**: `_517a1fbab7ba0c04`
- **Password**: `yIawHBFVcaiAKaJw`
- **Encryption Key**: `xqjMZ31ZIaAAn0ve0PA9JxLLKrfM5p4dd1m50__HoiE=`

### MariaDB Root Access

**Local MariaDB:**
- **Host**: `127.0.0.1` or `localhost`
- **Port**: `3306`
- **Username**: `root`
- **Password**: (empty - no password) or check your MariaDB configuration

## 🔌 Connection Strings

### For Local Development

**MySQL Connection String:**
```
mysql://_517a1fbab7ba0c04:yIawHBFVcaiAKaJw@127.0.0.1:3306/_517a1fbab7ba0c04
```

**JDBC Connection String:**
```
jdbc:mysql://127.0.0.1:3306/_517a1fbab7ba0c04?user=_517a1fbab7ba0c04&password=yIawHBFVcaiAKaJw
```

**Python (pymysql):**
```python
import pymysql
conn = pymysql.connect(
    host='127.0.0.1',
    port=3306,
    user='_517a1fbab7ba0c04',
    password='yIawHBFVcaiAKaJw',
    database='_517a1fbab7ba0c04',
    charset='utf8mb4'
)
```

### For Docker

**From Docker Container:**
- **Host**: `host.docker.internal` (macOS/Windows) or `172.17.0.1` (Linux)
- **Port**: `3306`
- **Database**: `_517a1fbab7ba0c04`
- **Username**: `_517a1fbab7ba0c04`
- **Password**: `yIawHBFVcaiAKaJw`

**MySQL Connection String (Docker):**
```
mysql://_517a1fbab7ba0c04:yIawHBFVcaiAKaJw@host.docker.internal:3306/_517a1fbab7ba0c04
```

## 💻 Command Line Connection

### Connect to Site Database

```bash
mysql -h 127.0.0.1 -P 3306 -u _517a1fbab7ba0c04 -pyIawHBFVcaiAKaJw _517a1fbab7ba0c04
```

### Connect as Root (if no password)

```bash
mysql -u root
# OR
sudo mysql -u root
```

### Connect as Root (if password set)

```bash
mysql -u root -p
# Enter password when prompted
```

### Using the Convenience Script

```bash
cd frappe-bench
./access_database.sh
```

## 🖥️ GUI Database Tools

### 1. TablePlus (Recommended for macOS)

**Install:**
```bash
brew install --cask tableplus
```

**Connect:**
1. Open TablePlus
2. Click "Create a new connection"
3. Select "MySQL"
4. Enter:
   - **Name**: VariPhi LMS
   - **Host**: `127.0.0.1`
   - **Port**: `3306`
   - **User**: `_517a1fbab7ba0c04`
   - **Password**: `yIawHBFVcaiAKaJw`
   - **Database**: `_517a1fbab7ba0c04`

**Or use connection string:**
```
mysql://_517a1fbab7ba0c04:yIawHBFVcaiAKaJw@127.0.0.1:3306/_517a1fbab7ba0c04
```

### 2. MySQL Workbench

**Install:**
```bash
brew install --cask mysql-workbench
```

**Connect:**
1. Open MySQL Workbench
2. Click "+" to add new connection
3. Enter:
   - **Connection Name**: VariPhi LMS
   - **Hostname**: `127.0.0.1`
   - **Port**: `3306`
   - **Username**: `_517a1fbab7ba0c04`
   - **Password**: `yIawHBFVcaiAKaJw`
   - **Default Schema**: `_517a1fbab7ba0c04`

### 3. DBeaver

**Install:**
```bash
brew install --cask dbeaver-community
```

**Connect:**
1. Open DBeaver
2. New Database Connection → MySQL
3. Enter:
   - **Host**: `127.0.0.1`
   - **Port**: `3306`
   - **Database**: `_517a1fbab7ba0c04`
   - **Username**: `_517a1fbab7ba0c04`
   - **Password**: `yIawHBFVcaiAKaJw`

### 4. Sequel Pro

**Install:**
```bash
brew install --cask sequel-pro
```

**Connect:**
1. Open Sequel Pro
2. Enter:
   - **Host**: `127.0.0.1`
   - **Username**: `_517a1fbab7ba0c04`
   - **Password**: `yIawHBFVcaiAKaJw`
   - **Database**: `_517a1fbab7ba0c04`
   - **Port**: `3306`

## 🔧 Quick Connection Commands

### Check Database Connection

```bash
mysql -h 127.0.0.1 -P 3306 -u _517a1fbab7ba0c04 -pyIawHBFVcaiAKaJw _517a1fbab7ba0c04 -e "SELECT 1"
```

### List All Tables

```bash
mysql -h 127.0.0.1 -P 3306 -u _517a1fbab7ba0c04 -pyIawHBFVcaiAKaJw _517a1fbab7ba0c04 -e "SHOW TABLES"
```

### Count Tables

```bash
mysql -h 127.0.0.1 -P 3306 -u _517a1fbab7ba0c04 -pyIawHBFVcaiAKaJw _517a1fbab7ba0c04 -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = '_517a1fbab7ba0c04'"
```

### View Database Size

```bash
mysql -h 127.0.0.1 -P 3306 -u _517a1fbab7ba0c04 -pyIawHBFVcaiAKaJw _517a1fbab7ba0c04 -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema = '_517a1fbab7ba0c04'"
```

## 🐳 Docker Connection

### From Host Machine to Local MariaDB

When running Docker, the container connects to local MariaDB using:
- **Host**: `host.docker.internal` (from inside container)
- **Port**: `3306`
- **Database**: `_517a1fbab7ba0c04`
- **Username**: `_517a1fbab7ba0c04`
- **Password**: `yIawHBFVcaiAKaJw`

### Connect from Docker Container

```bash
docker exec -it lms-frappe bash
mysql -h host.docker.internal -P 3306 -u _517a1fbab7ba0c04 -pyIawHBFVcaiAKaJw _517a1fbab7ba0c04
```

## 📝 Python Connection Example

```python
import pymysql
import frappe

# Method 1: Using pymysql directly
conn = pymysql.connect(
    host='127.0.0.1',
    port=3306,
    user='_517a1fbab7ba0c04',
    password='yIawHBFVcaiAKaJw',
    database='_517a1fbab7ba0c04',
    charset='utf8mb4'
)

cursor = conn.cursor()
cursor.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '_517a1fbab7ba0c04'")
result = cursor.fetchone()
print(f"Tables: {result[0]}")
conn.close()

# Method 2: Using Frappe (recommended)
frappe.init('vgi.local')
frappe.connect()
tables = frappe.db.sql("SHOW TABLES", as_dict=True)
print(f"Total tables: {len(tables)}")
frappe.destroy()
```

## 🔐 Security Notes

⚠️ **Important Security Information:**

1. **These credentials are for LOCAL DEVELOPMENT ONLY**
2. **Never commit these credentials to version control**
3. **Change all passwords before deploying to production**
4. **The database user has full access to the site database**

## 🛠️ Troubleshooting

### Connection Refused

**Check if MariaDB is running:**
```bash
brew services list | grep mariadb
```

**Start MariaDB:**
```bash
brew services start mariadb
```

**Check if port is listening:**
```bash
lsof -i :3306
```

### Access Denied

**Reset root password (if needed):**
```bash
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '';"
```

**Check user permissions:**
```bash
mysql -u root -e "SELECT User, Host FROM mysql.user WHERE User = '_517a1fbab7ba0c04';"
```

### Wrong Host

**If you see `host.docker.internal` in site config when running locally:**
```bash
cd frappe-bench
./bench-manage.sh start
# This automatically fixes the database host
```

## 📚 Additional Resources

- **Site Config**: `frappe-bench/sites/vgi.local/site_config.json`
- **Connection Script**: `frappe-bench/access_database.sh`
- **Open Database Helper**: `frappe-bench/open_database.sh`

## 🔄 Switching Between Local and Docker

### Local → Docker
The site config automatically updates to use `host.docker.internal` when Docker starts.

### Docker → Local
Run `./bench-manage.sh start` which automatically fixes the database host to `127.0.0.1`.

---

**Last Updated**: Based on current site configuration
**Site**: vgi.local
**Database**: _517a1fbab7ba0c04

