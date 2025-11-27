# No Hardcoded Values Policy

This document confirms that **all hardcoded values have been removed** from the codebase to ensure portability across different systems.

## ✅ What Has Been Made Dynamic

### 1. Database Credentials
- **Before**: Hardcoded in `create_db_user.sql`, `access_database.sh`, and documentation
- **After**: Auto-generated from `.env` file via `setup-env.sh`
- **Files Updated**:
  - `create_db_user.sql` - Now auto-generated (template provided)
  - `access_database.sh` - Reads from `.env` or `site_config.json`
  - All database credentials come from environment variables

### 2. Site Name
- **Before**: Hardcoded as `vgi.local` in multiple scripts
- **After**: Uses `SITE_NAME` environment variable (defaults to `vgi.local` if not set)
- **Files Updated**:
  - `bench-manage.sh` - Loads from `.env`
  - `setup-env.sh` - Uses `SITE_NAME` from `.env`
  - `fix-ui.sh` - Uses `SITE_NAME` from environment
  - `fix_database.py` - Uses `SITE_NAME` from environment
  - `bootstrap_db.py` - Uses `SITE_NAME` from environment
  - `auto_reinstall.exp` - Uses `SITE_NAME` from environment

### 3. Server URLs and Ports
- **Before**: Hardcoded `http://127.0.0.1:8000` in multiple places
- **After**: Uses `SITE_HOST` and `WEBSERVER_PORT` from `.env`
- **Files Updated**:
  - `bench-manage.sh` - All URLs use `${SITE_HOST}` variable
  - `setup-env.sh` - Generates configs from environment

### 4. User-Specific Values
- **Before**: Hardcoded `frappe_user: "shivam"` in config
- **After**: Auto-detected from system (`whoami`) or set in `.env`
- **Files Updated**:
  - `setup-env.sh` - Auto-detects `FRAPPE_USER`

### 5. Redis Configuration
- **Before**: Hardcoded Docker URLs (`redis://redis:6379`) in config
- **After**: Environment-aware (detects Docker vs local)
- **Files Updated**:
  - `setup-env.sh` - Detects Docker and adjusts Redis URLs
  - `common_site_config.json` - Generated from `.env`

### 6. Database Host
- **Before**: Hardcoded `host.docker.internal` or `127.0.0.1`
- **After**: Configurable via `DB_HOST` in `.env`
- **Files Updated**:
  - `setup-env.sh` - Uses `DB_HOST` from `.env`
  - Auto-detects Docker and adjusts if needed

## 📋 Configuration Sources

All configuration now comes from these sources (in order of priority):

1. **`.env` file** - Primary source (auto-generated from `.env.example`)
2. **Environment variables** - Can override `.env` values
3. **`site_config.json`** - Generated from `.env` (for Frappe)
4. **Defaults** - Sensible defaults if nothing is set

## 🔄 How to Regenerate Configs

If you need to regenerate all configuration files:

```bash
./setup-env.sh
```

This will:
- Read `.env` file
- Generate `common_site_config.json`
- Generate `site_config.json` (if site exists)
- Generate `create_db_user.sql`
- Regenerate Redis configs

## 📝 Files That Are Auto-Generated

These files are **auto-generated** and should **not be edited manually**:

- `sites/common_site_config.json` - Generated from `.env`
- `sites/*/site_config.json` - Generated from `.env`
- `create_db_user.sql` - Generated from `.env`
- `config/redis_*.conf` - Generated dynamically

## 🚫 Files Excluded from Git

These files contain system-specific or sensitive data and are excluded:

- `.env` - Contains all configuration
- `create_db_user.sql` - Contains database credentials
- `DATABASE_CREDENTIALS.txt` - Contains hardcoded credentials (legacy)
- `sites/*/site_config.json` - Contains site-specific config
- `sites/common_site_config.json` - Contains system config

## ✅ Verification

To verify no hardcoded values exist:

```bash
# Check for hardcoded site names
grep -r "vgi.local" --exclude-dir=node_modules --exclude-dir=.git --exclude="*.md" --exclude="*.txt" .

# Check for hardcoded database credentials
grep -r "_517a1fbab7ba0c04\|yIawHBFVcaiAKaJw" --exclude-dir=node_modules --exclude-dir=.git --exclude="*.md" --exclude="*.txt" .

# Check for hardcoded paths
./bench-manage.sh find-paths
```

**Note**: Documentation files (`.md`, `.txt`) may contain example values for reference, but these are not used by the code.

## 🎯 Summary

✅ **All hardcoded values have been removed from executable code**
✅ **All configuration comes from `.env` file**
✅ **All scripts use environment variables**
✅ **Auto-generation ensures no manual configuration needed**
✅ **System-specific files are excluded from git**

The codebase is now **fully portable** and can run on any system without conflicts!

