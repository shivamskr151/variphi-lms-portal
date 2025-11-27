#!/bin/bash
# Comprehensive Bench Management Script
# Handles all bench operations: setup, maintenance, site management, and verification

set -e

# Auto-detect bench directory (script location)
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BENCH_DIR"

# Site name and configuration - auto-detect from .env or use defaults
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$BENCH_DIR/.env" ]; then
    set -a
    source "$BENCH_DIR/.env"
    set +a
fi
SITE_NAME="${SITE_NAME:-vgi.local}"
WEBSERVER_PORT="${WEBSERVER_PORT:-8000}"
SITE_HOST="${SITE_HOST:-http://${DB_HOST:-127.0.0.1}:${WEBSERVER_PORT}}"

# Map DB_* variables to FRAPPE_DB_* if FRAPPE_DB_* are not set
# This allows using either naming convention
if [ -z "$FRAPPE_DB_HOST" ] && [ -n "$DB_HOST" ]; then
    export FRAPPE_DB_HOST="$DB_HOST"
fi
if [ -z "$FRAPPE_DB_PORT" ] && [ -n "$DB_PORT" ]; then
    export FRAPPE_DB_PORT="$DB_PORT"
fi
if [ -z "$FRAPPE_DB_NAME" ] && [ -n "$DB_NAME" ]; then
    export FRAPPE_DB_NAME="$DB_NAME"
fi
if [ -z "$FRAPPE_DB_USER" ] && [ -n "$DB_USER" ]; then
    export FRAPPE_DB_USER="$DB_USER"
fi
if [ -z "$FRAPPE_DB_PASSWORD" ] && [ -n "$DB_PASSWORD" ]; then
    export FRAPPE_DB_PASSWORD="$DB_PASSWORD"
fi

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

log_success() {
    echo -e "${GREEN}✓${NC}  $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

log_error() {
    echo -e "${RED}✗${NC}  $1"
}

# Activate virtual environment if it exists
activate_env() {
    if [ -f "$BENCH_DIR/env/bin/activate" ]; then
        source "$BENCH_DIR/env/bin/activate"
    else
        log_error "Virtual environment not found at $BENCH_DIR/env"
        return 1
    fi
}

# Check if bench is running
is_bench_running() {
    if pgrep -f "bench serve" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# COMMAND: check - Check setup and verify system
# =============================================================================
cmd_check() {
    echo "=== Checking Bench Setup ==="
    echo ""
    
    # Check virtual environment
    log_info "Checking virtual environment..."
    if [ -d "$BENCH_DIR/env" ]; then
        log_success "Virtual environment exists"
    else
        log_error "Virtual environment not found"
        return 1
    fi
    
    # Check bench structure
    log_info "Checking bench structure..."
    if [ -d "$BENCH_DIR/apps/frappe" ]; then
        log_success "Frappe app found"
    else
        log_error "Frappe app not found"
        return 1
    fi
    
    # Check site
    log_info "Checking site: $SITE_NAME"
    if [ -d "$BENCH_DIR/sites/$SITE_NAME" ]; then
        log_success "Site directory exists"
    else
        log_warning "Site directory not found"
    fi
    
    # Check Redis configs
    log_info "Checking Redis configs..."
    if [ -f "$BENCH_DIR/config/redis_cache.conf" ] && [ -f "$BENCH_DIR/config/redis_queue.conf" ]; then
        log_success "Redis configs exist"
    else
        log_warning "Redis configs missing, run: $0 fix-paths"
    fi
    
    # Check if bench is running
    log_info "Checking if bench is running..."
    if is_bench_running; then
        log_success "Bench is running"
    else
        log_info "Bench is not running"
    fi
    
    echo ""
    log_success "Setup check complete!"
}

# =============================================================================
# COMMAND: fix-env - Fix environment permissions and paths
# =============================================================================
cmd_fix_env() {
    echo "=== Fixing Virtual Environment ==="
    echo ""
    
    ENV_BIN_DIR="${BENCH_DIR}/env/bin"
    ENV_DIR="${BENCH_DIR}/env"
    
    if [ ! -d "$ENV_BIN_DIR" ]; then
        log_error "Virtual environment not found at ${ENV_BIN_DIR}"
        exit 1
    fi
    
    # Remove quarantine attributes from all files (macOS)
    log_info "Removing quarantine attributes..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        find "$ENV_BIN_DIR" -type f -exec xattr -d com.apple.quarantine {} \; 2>/dev/null || true
    fi
    
    # Add execute permissions
    log_info "Adding execute permissions..."
    chmod +x "$ENV_BIN_DIR"/* 2>/dev/null || true
    
    # Fix Windows path references in activation scripts
    log_info "Fixing path references in activation scripts..."
    # Only use OLD_BENCH_PATH if explicitly set, otherwise detect from activation scripts
    if [ -z "$OLD_BENCH_PATH" ]; then
        # Try to detect old path from activation script if it exists
        if [ -f "$ENV_DIR/bin/activate" ]; then
            # Use sed for portability (works on both macOS and Linux)
            OLD_PATH=$(grep '^VIRTUAL_ENV=' "$ENV_DIR/bin/activate" 2>/dev/null | sed 's/^VIRTUAL_ENV="\(.*\)"$/\1/' | head -1 || echo "")
        else
            OLD_PATH=""
        fi
    else
        OLD_PATH="$OLD_BENCH_PATH"
    fi
    NEW_PATH="$BENCH_DIR"
    
    # Only proceed if we have an old path to replace and it's different from new path
    if [ -z "$OLD_PATH" ] || [ "$OLD_PATH" = "$NEW_PATH" ]; then
        log_info "No path replacement needed"
        return 0
    fi
    
    log_info "Replacing old path: $OLD_PATH with new path: $NEW_PATH"
    
    # Fix shebang lines in all scripts
    if [[ "$OSTYPE" == "darwin"* ]]; then
        find "$ENV_BIN_DIR" -type f -exec sed -i '' "s|$OLD_PATH|$NEW_PATH|g" {} \; 2>/dev/null || true
    else
        find "$ENV_BIN_DIR" -type f -exec sed -i "s|$OLD_PATH|$NEW_PATH|g" {} \; 2>/dev/null || true
    fi
    
    # Fix activation scripts
    for activate_script in "$ENV_DIR/bin/activate" "$ENV_DIR/bin/activate.csh" "$ENV_DIR/bin/activate.fish"; do
        if [ -f "$activate_script" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|$OLD_PATH|$NEW_PATH|g" "$activate_script" 2>/dev/null || true
            else
                sed -i "s|$OLD_PATH|$NEW_PATH|g" "$activate_script" 2>/dev/null || true
            fi
        fi
    done
    
    # Upgrade virtual environment
    log_info "Upgrading virtual environment..."
    PYTHON_CMD=""
    for py in python3.13 python3.14 python3.12 python3; do
        if command -v "$py" >/dev/null 2>&1; then
            PYTHON_CMD=$(command -v "$py")
            break
        fi
    done
    
    if [ -z "$PYTHON_CMD" ]; then
        log_warning "No Python interpreter found, skipping venv upgrade"
    else
        "$PYTHON_CMD" -m venv --upgrade "$ENV_DIR" 2>/dev/null || true
    fi
    
    echo ""
    log_success "Virtual environment fixed successfully!"
}

# =============================================================================
# COMMAND: fix-paths - Make all paths dynamic and regenerate configs
# =============================================================================
cmd_fix_paths() {
    echo "=== Making All Paths Dynamic ==="
    echo "Bench directory: $BENCH_DIR"
    echo ""
    
    # Regenerate Redis configs
    log_info "Regenerating Redis configuration files..."
    export FRAPPE_BENCH_ROOT="$BENCH_DIR"
    if [ -f "$BENCH_DIR/config/generate_redis_configs.sh" ]; then
        "$BENCH_DIR/config/generate_redis_configs.sh"
        log_success "Redis configs regenerated"
    else
        log_error "Redis config generator not found"
        return 1
    fi
    
    # Ensure pids directory exists
    mkdir -p "$BENCH_DIR/config/pids" 2>/dev/null || true
    
    echo ""
    log_success "All paths are now dynamic!"
    log_info "Redis configs have been regenerated with current bench path"
}

# =============================================================================
# COMMAND: setup-env - Setup environment configuration
# =============================================================================
cmd_setup_env() {
    echo "=== Setting Up Environment Configuration ==="
    echo ""
    
    if [ -f "$BENCH_DIR/setup-env.sh" ]; then
        log_info "Running setup-env.sh..."
        chmod +x "$BENCH_DIR/setup-env.sh"
        "$BENCH_DIR/setup-env.sh"
        log_success "Environment setup complete!"
    else
        log_error "setup-env.sh not found at $BENCH_DIR/setup-env.sh"
        return 1
    fi
}

# =============================================================================
# COMMAND: find-paths - Find hardcoded paths in the project
# =============================================================================
cmd_find_paths() {
    echo "=== Finding Hardcoded Paths ==="
    echo "Bench directory: $BENCH_DIR"
    echo ""
    
    log_info "Checking for hardcoded bench paths..."
    CURRENT_PATH=$(pwd)
    
    # Search for the current bench path
    results=$(grep -r "$CURRENT_PATH" \
        --exclude-dir=env \
        --exclude-dir=logs \
        --exclude-dir=.git \
        --exclude-dir=node_modules \
        --exclude="*.log" \
        --exclude="*.pyc" \
        --exclude="*.pyo" \
        --exclude="*.rdb" \
        --exclude="*.pid" \
        --exclude="*.map" \
        . 2>/dev/null | grep -v "^Binary" | head -20)
    
    if [ -n "$results" ]; then
        echo "$results"
    else
        log_success "No hardcoded paths found"
    fi
    
    echo ""
    log_info "Checking for common hardcoded path patterns..."
    
    # Check for other common hardcoded paths
    PATTERNS=(
        "/Users/"
        "/home/"
        "/mnt/d/"
        "/tmp/frappe"
    )
    
    for pattern in "${PATTERNS[@]}"; do
        count=$(grep -r "$pattern" \
            --exclude-dir=env \
            --exclude-dir=logs \
            --exclude-dir=.git \
            --exclude-dir=node_modules \
            --exclude="*.log" \
            --exclude="*.pyc" \
            --exclude="*.pyo" \
            --exclude="*.rdb" \
            --exclude="*.pid" \
            . 2>/dev/null | grep -v "^Binary" | wc -l | tr -d ' ')
        
        if [ "$count" -gt 0 ]; then
            log_warning "Found $count instances of: $pattern"
            grep -r "$pattern" \
                --exclude-dir=env \
                --exclude-dir=logs \
                --exclude-dir=.git \
                --exclude-dir=node_modules \
                --exclude="*.log" \
                --exclude="*.pyc" \
                --exclude="*.pyo" \
                --exclude="*.rdb" \
                --exclude="*.pid" \
                . 2>/dev/null | grep -v "^Binary" | head -5
            echo ""
        fi
    done
    
    echo ""
    log_info "Note: Some paths in documentation files are expected."
    log_info "Focus on fixing paths in configuration files, scripts, and Procfile."
}

# =============================================================================
# COMMAND: stop - Stop all bench processes
# =============================================================================
cmd_stop() {
    echo "=== Stopping Bench Processes ==="
    echo ""
    
    log_info "Stopping all bench processes..."
    
    # Kill processes on specific ports
    WEBSERVER_PORT="${WEBSERVER_PORT:-8000}"
    SOCKETIO_PORT="${SOCKETIO_PORT:-9000}"
    REDIS_QUEUE_PORT="${REDIS_QUEUE_PORT:-11000}"
    REDIS_CACHE_PORT="${REDIS_CACHE_PORT:-13000}"
    lsof -ti:"$WEBSERVER_PORT","$SOCKETIO_PORT","$REDIS_QUEUE_PORT","$REDIS_CACHE_PORT" 2>/dev/null | xargs kill -9 2>/dev/null || true
    
    # Kill bench-related processes
    pkill -f "bench start" 2>/dev/null || true
    pkill -f "redis-server" 2>/dev/null || true
    pkill -f "gunicorn" 2>/dev/null || true
    pkill -f "socketio" 2>/dev/null || true
    pkill -f "frappe.*worker" 2>/dev/null || true
    pkill -f "frappe.*schedule" 2>/dev/null || true
    pkill -f "frappe.*watch" 2>/dev/null || true
    
    sleep 2
    
    log_success "All processes stopped. Ports freed."
}

# =============================================================================
# Helper: Auto-detect and fix database port
# =============================================================================
fix_database_port() {
    log_info "Auto-detecting database port..."
    
    # Use DB_PORT from .env, or detect which port MariaDB is actually running on
    DB_PORT="${DB_PORT:-3306}"
    DOCKER_DB_PORT="${DOCKER_DB_PORT:-3307}"
    
    if lsof -Pi :"$DB_PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_success "MariaDB detected on port $DB_PORT (local)"
    elif lsof -Pi :"$DOCKER_DB_PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
        DB_PORT="$DOCKER_DB_PORT"
        log_success "MariaDB detected on port $DB_PORT (Docker)"
    else
        log_warning "MariaDB not detected on ports $DB_PORT or $DOCKER_DB_PORT, using default $DB_PORT"
    fi
    
    # Update all site configs to use the correct port
    if [ -d "$BENCH_DIR/sites" ]; then
        for site_config in "$BENCH_DIR/sites"/*/site_config.json; do
            if [ -f "$site_config" ]; then
                CURRENT_PORT=$(python3 -c "import json; f=open('$site_config'); c=json.load(f); print(c.get('db_port', ${DB_PORT:-3306})); f.close()" 2>/dev/null || echo "${DB_PORT:-3306}")
                DB_HOST=$(python3 -c "import json; f=open('$site_config'); c=json.load(f); print(c.get('db_host', '${DB_HOST:-127.0.0.1}')); f.close()" 2>/dev/null || echo "${DB_HOST:-127.0.0.1}")
                
                # Fix host if it's set to Docker values (mariadb, host.docker.internal)
                # or if port needs updating for local development
                NEEDS_UPDATE=false
                if [ "$DB_HOST" = "mariadb" ] || [ "$DB_HOST" = "host.docker.internal" ]; then
                    NEEDS_UPDATE=true
                elif [ "$DB_HOST" = "${DB_HOST:-127.0.0.1}" ] || [ "$DB_HOST" = "localhost" ]; then
                    if [ "$CURRENT_PORT" != "$DB_PORT" ]; then
                        NEEDS_UPDATE=true
                    fi
                fi
                
                if [ "$NEEDS_UPDATE" = true ]; then
                    DB_HOST="${DB_HOST:-127.0.0.1}" \
                    DB_PORT="$DB_PORT" \
                    python3 << PYEOF
import json
import os
import sys

try:
    with open('$site_config', 'r') as f:
        config = json.load(f)
    
    db_host = os.environ.get('DB_HOST', '127.0.0.1')
    old_host = config.get('db_host', db_host)
    old_port = config.get('db_port', int(os.environ.get('DB_PORT', '3306')))
    
    # Always set to local for local development
    config['db_port'] = $DB_PORT
    config['db_host'] = db_host
    
    with open('$site_config', 'w') as f:
        json.dump(config, f, indent=1)
    
    site_name = '$site_config'.split('/')[-2]
    if old_host != db_host or old_port != $DB_PORT:
        print(f"   Updated {site_name}: {old_host}:{old_port} -> {db_host}:$DB_PORT")
    else:
        print(f"   Verified {site_name}: {db_host}:$DB_PORT")
except Exception as e:
    print(f"   Error updating $site_config: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
                fi
            fi
        done
    fi
}

# =============================================================================
# Helper: Ensure Home folder exists for file uploads
# =============================================================================
ensure_home_folder() {
    log_info "Ensuring file storage directories and Home folder exist..."
    
    # Ensure public/files directory exists
    local files_dir="$BENCH_DIR/sites/$SITE_NAME/public/files"
    if [ ! -d "$files_dir" ]; then
        log_info "Creating public/files directory..."
        mkdir -p "$files_dir"
        chmod 755 "$files_dir"
        log_success "Created public/files directory"
    fi
    
    # Ensure private/files directory exists
    local private_files_dir="$BENCH_DIR/sites/$SITE_NAME/private/files"
    if [ ! -d "$private_files_dir" ]; then
        log_info "Creating private/files directory..."
        mkdir -p "$private_files_dir"
        chmod 755 "$private_files_dir"
        log_success "Created private/files directory"
    fi
    
    # Try to create Home folder in database (non-blocking - will fail gracefully if site not ready)
    activate_env
    
    # Use bench console to create Home folder if it doesn't exist
    local home_folder_result=$(bench --site "$SITE_NAME" console << 'PYEOF' 2>&1
import frappe
import sys

try:
    frappe.init(site="$SITE_NAME")
    frappe.connect()
    
    # Check if Home folder exists
    home_exists = frappe.db.exists("File", {"is_home_folder": 1})
    
    if not home_exists:
        from frappe.core.doctype.file.utils import make_home_folder
        make_home_folder()
        frappe.db.commit()
        print("CREATED")
    else:
        print("EXISTS")
    
    frappe.db.close()
    sys.exit(0)
except Exception as e:
    # Site might not be ready yet - this is OK
    print(f"SKIP:{str(e)[:50]}")
    sys.exit(0)
PYEOF
)
    
    if echo "$home_folder_result" | grep -q "CREATED"; then
        log_success "Home folder created in database"
    elif echo "$home_folder_result" | grep -q "EXISTS"; then
        log_success "Home folder already exists in database"
    else
        # Site might not be ready yet - this is OK, Home folder will be created on first file upload
        log_info "Home folder will be created automatically on first file upload"
    fi
}

# =============================================================================
# Helper: Fix asset symlinks to ensure icons are accessible
# =============================================================================
fix_assets_symlinks() {
    log_info "Ensuring asset symlinks are correct..."
    
    # Check if frappe assets need fixing
    FIX_NEEDED=false
    
    # Check if frappe is a directory instead of symlink, or if icons are missing
    if [ -d "$BENCH_DIR/sites/assets/frappe" ] && [ ! -L "$BENCH_DIR/sites/assets/frappe" ]; then
        if [ ! -d "$BENCH_DIR/sites/assets/frappe/icons" ]; then
            FIX_NEEDED=true
        fi
    elif [ -L "$BENCH_DIR/sites/assets/frappe" ]; then
        LINK_TARGET=$(readlink "$BENCH_DIR/sites/assets/frappe" 2>/dev/null || echo "")
        if echo "$LINK_TARGET" | grep -q "/home/frappe" || [ ! -d "$BENCH_DIR/sites/assets/frappe/icons" ]; then
            FIX_NEEDED=true
        fi
    else
        FIX_NEEDED=true
    fi
    
    if [ "$FIX_NEEDED" = true ]; then
        log_info "Fixing asset symlinks..."
        # Remove broken symlinks or directories
        rm -rf "$BENCH_DIR/sites/assets/frappe" "$BENCH_DIR/sites/assets/lms" "$BENCH_DIR/sites/assets/payments" 2>/dev/null || true
        
        # Recreate symlinks using bench build
        activate_env
        bench build --using-cached > /dev/null 2>&1 || {
            # Fallback: manually create symlinks if bench build fails
            if [ -d "$BENCH_DIR/apps/frappe/frappe/public" ]; then
                ln -sf "$BENCH_DIR/apps/frappe/frappe/public" "$BENCH_DIR/sites/assets/frappe" 2>/dev/null || true
            fi
            if [ -d "$BENCH_DIR/apps/lms/lms/public" ]; then
                ln -sf "$BENCH_DIR/apps/lms/lms/public" "$BENCH_DIR/sites/assets/lms" 2>/dev/null || true
            fi
        }
        log_success "Asset symlinks fixed"
    fi
}

# =============================================================================
# COMMAND: start - Start bench
# =============================================================================
cmd_start() {
    echo "=== Starting Bench ==="
    echo ""
    
    # Load Redis ports from .env early so they're available everywhere
    # ALWAYS use ports to construct URLs (ignore any existing REDIS_CACHE/REDIS_QUEUE values that might be wrong)
    REDIS_CACHE_PORT="${REDIS_CACHE_PORT:-13000}"
    REDIS_QUEUE_PORT="${REDIS_QUEUE_PORT:-11000}"
    # Force correct Redis URLs based on ports (don't trust .env values that might be wrong)
    REDIS_CACHE="redis://127.0.0.1:${REDIS_CACHE_PORT}"
    REDIS_QUEUE="redis://127.0.0.1:${REDIS_QUEUE_PORT}"
    REDIS_SOCKETIO="redis://127.0.0.1:${REDIS_QUEUE_PORT}"
    
    # Export Redis environment variables at script level so they're available to all child processes
    export FRAPPE_REDIS_CACHE="$REDIS_CACHE"
    export FRAPPE_REDIS_QUEUE="$REDIS_QUEUE"
    export FRAPPE_REDIS_SOCKETIO="$REDIS_SOCKETIO"
    
    # Restore local configuration if it was overwritten by Docker
    NEEDS_RESTORE=false
    if [ -f "$BENCH_DIR/sites/common_site_config.json" ]; then
        REDIS_QUEUE_CHECK=$(python3 -c "import json; f=open('$BENCH_DIR/sites/common_site_config.json'); c=json.load(f); print(c.get('redis_queue', '')); f.close()" 2>/dev/null || echo "")
        if echo "$REDIS_QUEUE_CHECK" | grep -q "redis://redis:6379"; then
            NEEDS_RESTORE=true
        fi
    fi
    
    # Check if any site config has Docker database host
    if [ -d "$BENCH_DIR/sites" ]; then
        for site_config in "$BENCH_DIR/sites"/*/site_config.json; do
            if [ -f "$site_config" ]; then
                DB_HOST=$(python3 -c "import json; f=open('$site_config'); c=json.load(f); print(c.get('db_host', '')); f.close()" 2>/dev/null || echo "")
                if [ "$DB_HOST" = "mariadb" ]; then
                    NEEDS_RESTORE=true
                    break
                fi
            fi
        done
    fi
    
    if [ "$NEEDS_RESTORE" = true ]; then
        log_info "Restoring local configuration (was set to Docker values)..."
        if [ -f "$BENCH_DIR/restore-local-config.sh" ]; then
            "$BENCH_DIR/restore-local-config.sh" > /dev/null 2>&1
        fi
    fi
    
    # Auto-detect and fix database port (PERMANENT FIX)
    fix_database_port
    
    # Ensure Home folder exists for file uploads (PERMANENT FIX)
    ensure_home_folder
    
    # Fix asset symlinks to ensure icons are accessible (PERMANENT FIX)
    fix_assets_symlinks
    
    # Sync site_config.json with .env file
    sync_site_config_from_env() {
        local site_dir="$BENCH_DIR/sites/$SITE_NAME"
        local site_config="$site_dir/site_config.json"
        
        if [ ! -f "$site_config" ]; then
            log_warning "Site config not found: $site_config"
            return 0
        fi
        
        # Ensure variables are exported
        export DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD
        
        if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
            log_warning "Database credentials not found in .env file"
            return 0
        fi
        
        log_info "Syncing site_config.json with .env file..."
        if ! SITE_CONFIG_PATH="$site_config" \
             DB_HOST="${DB_HOST:-127.0.0.1}" \
             DB_PORT="${DB_PORT:-3306}" \
             DB_NAME="$DB_NAME" \
             DB_USER="$DB_USER" \
             DB_PASSWORD="$DB_PASSWORD" \
             python3 << 'PYEOF'
import json
import os

site_config = os.environ.get('SITE_CONFIG_PATH', '')
db_host = os.environ.get('DB_HOST', os.environ.get('FRAPPE_DB_HOST', '127.0.0.1'))
db_port = int(os.environ.get('DB_PORT', os.environ.get('FRAPPE_DB_PORT', '3306')))
db_name = os.environ.get('DB_NAME', '')
db_user = os.environ.get('DB_USER', '')
db_password = os.environ.get('DB_PASSWORD', '')

try:
    with open(site_config, 'r') as f:
        config = json.load(f)
    
    old_host = config.get('db_host', '')
    old_port = config.get('db_port', 0)
    old_name = config.get('db_name', '')
    old_user = config.get('db_user', '')
    
    # Update database configuration from .env
    config['db_host'] = db_host
    config['db_port'] = db_port
    if db_name:
        config['db_name'] = db_name
    if db_user:
        config['db_user'] = db_user
    if db_password:
        config['db_password'] = db_password
    # Remove socket setting if it exists
    if 'db_socket' in config:
        del config['db_socket']
    
    with open(site_config, 'w') as f:
        json.dump(config, f, indent=1)
    
    changes = []
    if old_host != db_host or old_port != db_port:
        changes.append(f'host:port from {old_host}:{old_port} to {db_host}:{db_port}')
    if db_name and old_name != db_name:
        changes.append(f'database from {old_name} to {db_name}')
    if db_user and old_user != db_user:
        changes.append(f'user from {old_user} to {db_user}')
    
    if changes:
        print(f'✅ Updated site database configuration: {", ".join(changes)}')
    else:
        print(f'✅ Site database configuration is up to date')
except Exception as e:
    print(f'⚠️  Could not update site config: {e}')
PYEOF
        then
            log_warning "Failed to sync site_config.json"
        fi
    }
    
    sync_site_config_from_env
    
    # Ensure assets are built before starting (fixes 404 errors for CSS/JS bundles)
    ensure_assets_built() {
        local assets_json="$BENCH_DIR/sites/assets/assets.json"
        local needs_build=false
        
        # Quick check: if assets.json doesn't exist or is empty, we need to build
        if [ ! -f "$assets_json" ] || [ ! -s "$assets_json" ]; then
            needs_build=true
            log_info "assets.json missing or empty, assets need to be built"
        else
            # Check if files referenced in assets.json actually exist on disk
            # This catches cases where assets.json is out of sync with actual files
            log_info "Verifying asset files exist..."
            
            # Use Python to check if files referenced in assets.json exist
            # Capture output separately to avoid interfering with exit code
            local check_result=$(python3 << PYEOF 2>&1
import json
import os
import sys

assets_json = "$assets_json"
bench_dir = "$BENCH_DIR"

try:
    with open(assets_json, 'r') as f:
        assets = json.load(f)
    
    missing = []
    for bundle_name, asset_path in assets.items():
        if asset_path.startswith('/'):
            # Remove leading slash and prepend bench_dir/sites
            file_path = os.path.join(bench_dir, 'sites', asset_path.lstrip('/'))
        else:
            file_path = os.path.join(bench_dir, 'sites', 'assets', asset_path)
        
        if not os.path.exists(file_path):
            missing.append((bundle_name, asset_path))
    
    if missing:
        # Print to stderr so it doesn't interfere with return value
        print(f"MISSING_FILES:{len(missing)}", file=sys.stderr)
        # Print first few missing files for debugging
        for bundle, path in missing[:5]:
            print(f"  - {bundle}: {path}", file=sys.stderr)
        sys.exit(1)
    else:
        print("ALL_FILES_EXIST", file=sys.stderr)
        sys.exit(0)
except Exception as e:
    print(f"ERROR checking assets: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
)
            
            if [ $? -ne 0 ]; then
                needs_build=true
                log_warning "Some asset files referenced in assets.json are missing"
                echo "$check_result" | grep -E "(MISSING_FILES|  -)" | while read line; do
                    log_info "$line"
                done
            else
                log_success "All asset files verified"
            fi
            
            # Also check if dist directories exist and have files
            local frappe_dist="$BENCH_DIR/sites/assets/frappe/dist/css"
            local lms_dist="$BENCH_DIR/sites/assets/lms/dist/css"
            
            if [ ! -d "$frappe_dist" ] || [ -z "$(ls -A "$frappe_dist" 2>/dev/null)" ]; then
                needs_build=true
                log_info "Frappe CSS bundles missing, assets need to be built"
            elif [ ! -d "$lms_dist" ] || [ -z "$(ls -A "$lms_dist" 2>/dev/null)" ]; then
                needs_build=true
                log_info "LMS CSS bundles missing, assets need to be built"
            fi
        fi
        
        if [ "$needs_build" = true ]; then
            log_info "Building assets (this may take a minute)..."
            activate_env
            
            # Verify bench command is available
            if ! command -v bench >/dev/null 2>&1; then
                log_error "bench command not found. Make sure virtual environment is activated."
                return 1
            fi
            
            # Remove old assets.json to force fresh build if it has wrong references
            if [ -f "$assets_json" ]; then
                log_info "Removing outdated assets.json to force fresh build..."
                rm -f "$assets_json"
            fi
            
            # Also remove any stale bundle files that might cause conflicts
            log_info "Cleaning old asset bundles..."
            find "$BENCH_DIR/sites/assets" -name "*.bundle.*.css" -type f -mtime +1 -delete 2>/dev/null || true
            find "$BENCH_DIR/sites/assets" -name "*.bundle.*.js" -type f -mtime +1 -delete 2>/dev/null || true
            
            # Build assets for all apps with --force to ensure fresh build
            local build_success=false
            if bench build --force > /tmp/bench-build.log 2>&1; then
                build_success=true
            else
                log_warning "Asset build with --force had issues, trying without --force..."
                if bench build > /tmp/bench-build.log 2>&1; then
                    build_success=true
                fi
            fi
            
            if [ "$build_success" = true ]; then
                # Wait a moment for filesystem to sync
                sleep 1
                
                # Verify files exist after build
                log_info "Verifying built assets..."
                local verify_result=$(python3 << PYEOF 2>&1
import json
import os
import sys

assets_json = "$assets_json"
bench_dir = "$BENCH_DIR"

try:
    if not os.path.exists(assets_json):
        print("ERROR: assets.json not created after build", file=sys.stderr)
        sys.exit(1)
    
    with open(assets_json, 'r') as f:
        assets = json.load(f)
    
    missing = []
    for bundle_name, asset_path in assets.items():
        if asset_path.startswith('/'):
            file_path = os.path.join(bench_dir, 'sites', asset_path.lstrip('/'))
        else:
            file_path = os.path.join(bench_dir, 'sites', 'assets', asset_path)
        
        if not os.path.exists(file_path):
            missing.append((bundle_name, asset_path))
    
    if missing:
        print(f"WARNING: {len(missing)} files still missing after build", file=sys.stderr)
        for bundle, path in missing[:5]:
            print(f"  - {bundle}: {path}", file=sys.stderr)
        sys.exit(1)
    else:
        print("SUCCESS: All asset files verified", file=sys.stderr)
        sys.exit(0)
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
)
                
                if [ $? -eq 0 ]; then
                    log_success "Assets built and verified successfully"
                else
                    log_warning "Assets built but verification found issues:"
                    echo "$verify_result" | grep -E "(WARNING|  -)" | while read line; do
                        log_info "$line"
                    done
                    log_info "This may resolve after the first page load"
                fi
                
                # Clear cache after building
                bench --site "$SITE_NAME" clear-cache > /dev/null 2>&1 || true
            else
                log_error "Asset build failed. Check /tmp/bench-build.log for details"
                log_info "You can manually build assets with: bench build"
                # Don't exit - let bench start anyway, assets might work
            fi
        else
            log_success "Assets are up to date"
        fi
    }
    
    ensure_assets_built
    
    # Fix Redis configuration in common_site_config.json
    fix_redis_config() {
        log_info "Ensuring Redis configuration is correct..."
        
        # Use the Redis variables already set at function start (from .env or defaults)
        # These are already exported at the script level
        
        local config_file="$BENCH_DIR/sites/common_site_config.json"
        if [ ! -f "$config_file" ]; then
            log_warning "common_site_config.json not found, will be created by setup-env.sh"
            return 0
        fi
        
        # Always update Redis config to ensure it's correct (no conditional check)
        log_info "Updating Redis configuration to use local ports..."
        python3 << PYEOF
import json
import os
import sys

config_file = "${config_file}"
redis_cache = "${REDIS_CACHE}"
redis_queue = "${REDIS_QUEUE}"
redis_socketio = "${REDIS_SOCKETIO}"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    old_cache = config.get('redis_cache', '')
    old_queue = config.get('redis_queue', '')
    old_socketio = config.get('redis_socketio', '')
    
    # Always update to ensure correct values
    config['redis_cache'] = redis_cache
    config['redis_queue'] = redis_queue
    config['redis_socketio'] = redis_socketio
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=1)
    
    changes = []
    if old_cache != redis_cache:
        changes.append(f'cache: {old_cache} -> {redis_cache}')
    if old_queue != redis_queue:
        changes.append(f'queue: {old_queue} -> {redis_queue}')
    if old_socketio != redis_socketio:
        changes.append(f'socketio: {old_socketio} -> {redis_socketio}')
    
    if changes:
        print(f"✅ Updated Redis configuration: {', '.join(changes)}")
    else:
        print(f"✅ Redis configuration verified: cache={redis_cache}, queue={redis_queue}, socketio={redis_socketio}")
except Exception as e:
    print(f"❌ Could not update Redis config: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
        if [ $? -ne 0 ]; then
            log_error "Failed to update Redis configuration"
            return 1
        fi
    }
    
    fix_redis_config
    
    # Ensure Redis configs are up to date
    log_info "Ensuring Redis configs are up to date..."
    export FRAPPE_BENCH_ROOT="$BENCH_DIR"
    if [ -f "$BENCH_DIR/config/generate_redis_configs.sh" ]; then
        "$BENCH_DIR/config/generate_redis_configs.sh" > /dev/null 2>&1
    fi
    
    # Check and fix node_modules for platform mismatch (Docker -> Local)
    fix_node_modules_platform() {
        log_info "Checking node_modules for platform compatibility..."
        
        local needs_reinstall=false
        local current_platform=""
        
        # Detect current platform
        case "$(uname -s)" in
            Darwin*)
                case "$(uname -m)" in
                    arm64) current_platform="darwin-arm64" ;;
                    x86_64) current_platform="darwin-x64" ;;
                esac
                ;;
            Linux*)
                case "$(uname -m)" in
                    aarch64|arm64) current_platform="linux-arm64" ;;
                    x86_64) current_platform="linux-x64" ;;
                esac
                ;;
        esac
        
        if [ -z "$current_platform" ]; then
            log_warning "Could not detect platform, skipping node_modules check"
            return 0
        fi
        
        # Check frappe app
        if [ -d "$BENCH_DIR/apps/frappe/node_modules/@esbuild" ]; then
            if [ ! -d "$BENCH_DIR/apps/frappe/node_modules/@esbuild/$current_platform" ]; then
                # Check if there are Linux binaries when we're on macOS (or vice versa)
                if [ "$(uname -s)" = "Darwin" ] && [ -d "$BENCH_DIR/apps/frappe/node_modules/@esbuild/linux-arm64" ]; then
                    needs_reinstall=true
                    log_warning "Detected Linux esbuild binaries in frappe (from Docker), need to reinstall for macOS"
                elif [ "$(uname -s)" = "Linux" ] && [ -d "$BENCH_DIR/apps/frappe/node_modules/@esbuild/darwin-arm64" ]; then
                    needs_reinstall=true
                    log_warning "Detected macOS esbuild binaries in frappe, need to reinstall for Linux"
                fi
            fi
        fi
        
        # Check lms app
        if [ -d "$BENCH_DIR/apps/lms/node_modules/@esbuild" ]; then
            if [ ! -d "$BENCH_DIR/apps/lms/node_modules/@esbuild/$current_platform" ]; then
                # Check if there are Linux binaries when we're on macOS (or vice versa)
                if [ "$(uname -s)" = "Darwin" ] && [ -d "$BENCH_DIR/apps/lms/node_modules/@esbuild/linux-arm64" ]; then
                    needs_reinstall=true
                    log_warning "Detected Linux esbuild binaries in lms (from Docker), need to reinstall for macOS"
                elif [ "$(uname -s)" = "Linux" ] && [ -d "$BENCH_DIR/apps/lms/node_modules/@esbuild/darwin-arm64" ]; then
                    needs_reinstall=true
                    log_warning "Detected macOS esbuild binaries in lms, need to reinstall for Linux"
                fi
            fi
        fi
        
        if [ "$needs_reinstall" = true ]; then
            log_info "Reinstalling node_modules for macOS compatibility..."
            
            # Reinstall frappe node_modules
            if [ -d "$BENCH_DIR/apps/frappe" ] && [ -f "$BENCH_DIR/apps/frappe/package.json" ]; then
                log_info "Reinstalling frappe node_modules..."
                cd "$BENCH_DIR/apps/frappe"
                if [ -f "yarn.lock" ]; then
                    rm -rf node_modules/@esbuild 2>/dev/null || true
                    yarn install --force --network-timeout 600000 > /tmp/frappe-yarn-reinstall.log 2>&1 || {
                        log_warning "Frappe yarn reinstall had issues, but continuing..."
                    }
                elif [ -f "package-lock.json" ]; then
                    rm -rf node_modules/@esbuild 2>/dev/null || true
                    npm ci --force > /tmp/frappe-npm-reinstall.log 2>&1 || {
                        log_warning "Frappe npm reinstall had issues, but continuing..."
                    }
                fi
                cd "$BENCH_DIR"
            fi
            
            # Reinstall lms node_modules
            if [ -d "$BENCH_DIR/apps/lms" ] && [ -f "$BENCH_DIR/apps/lms/package.json" ]; then
                log_info "Reinstalling lms node_modules..."
                cd "$BENCH_DIR/apps/lms"
                if [ -f "yarn.lock" ]; then
                    rm -rf node_modules/@esbuild 2>/dev/null || true
                    yarn install --force --network-timeout 600000 > /tmp/lms-yarn-reinstall.log 2>&1 || {
                        log_warning "LMS yarn reinstall had issues, but continuing..."
                    }
                elif [ -f "package-lock.json" ]; then
                    rm -rf node_modules/@esbuild 2>/dev/null || true
                    npm ci --force > /tmp/lms-npm-reinstall.log 2>&1 || {
                        log_warning "LMS npm reinstall had issues, but continuing..."
                    }
                fi
                cd "$BENCH_DIR"
            fi
            
            log_success "Node modules reinstalled for macOS"
        else
            log_success "Node modules are compatible with current platform"
        fi
    }
    
    fix_node_modules_platform
    
    # Export environment variables for Frappe (Frappe checks env vars first)
    export FRAPPE_DB_HOST="${FRAPPE_DB_HOST:-${DB_HOST}}"
    export FRAPPE_DB_PORT="${FRAPPE_DB_PORT:-${DB_PORT}}"
    export FRAPPE_DB_NAME="${FRAPPE_DB_NAME:-${DB_NAME}}"
    export FRAPPE_DB_USER="${FRAPPE_DB_USER:-${DB_USER}}"
    export FRAPPE_DB_PASSWORD="${FRAPPE_DB_PASSWORD:-${DB_PASSWORD}}"
    export FRAPPE_DB_SOCKET=""
    
    # Redis environment variables are already set in fix_redis_config()
    # These will be used by socketio/node_utils.js if FRAPPE_REDIS_QUEUE is set
    # Make sure they're exported for the bench start process
    export FRAPPE_REDIS_CACHE="${FRAPPE_REDIS_CACHE:-redis://127.0.0.1:${REDIS_CACHE_PORT:-13000}}"
    export FRAPPE_REDIS_QUEUE="${FRAPPE_REDIS_QUEUE:-redis://127.0.0.1:${REDIS_QUEUE_PORT:-11000}}"
    
    # Check if already running
    if is_bench_running; then
        log_warning "Bench is already running"
        return 0
    fi
    
    log_info "Starting bench..."
    activate_env
    bench start
}

# =============================================================================
# COMMAND: restart - Restart bench
# =============================================================================
cmd_restart() {
    echo "=== Restarting Bench ==="
    echo ""
    
    cmd_stop
    sleep 2
    cmd_start
}

# =============================================================================
# COMMAND: status - Check bench status
# =============================================================================
cmd_status() {
    echo "=== Bench Status ==="
    echo ""
    
    if is_bench_running; then
        log_success "Bench is running"
        
        # Check ports
        log_info "Checking ports..."
        WEBSERVER_PORT="${WEBSERVER_PORT:-8000}"
        SOCKETIO_PORT="${SOCKETIO_PORT:-9000}"
        REDIS_QUEUE_PORT="${REDIS_QUEUE_PORT:-11000}"
        REDIS_CACHE_PORT="${REDIS_CACHE_PORT:-13000}"
        for port in "$WEBSERVER_PORT" "$SOCKETIO_PORT" "$REDIS_QUEUE_PORT" "$REDIS_CACHE_PORT"; do
            if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                log_success "Port $port is in use"
            else
                log_warning "Port $port is not in use"
            fi
        done
    else
        log_info "Bench is not running"
    fi
    
    echo ""
    
    # Check site
    log_info "Site: $SITE_NAME"
    if [ -d "$BENCH_DIR/sites/$SITE_NAME" ]; then
        log_success "Site directory exists"
    else
        log_warning "Site directory not found"
    fi
}

# =============================================================================
# COMMAND: redis-cache - Start Redis cache
# =============================================================================
cmd_redis_cache() {
    log_info "Starting Redis cache..."
    
    # Ensure pids directory exists
    mkdir -p "$BENCH_DIR/config/pids"
    
    # Always regenerate Redis configs with current bench path before starting
    export FRAPPE_BENCH_ROOT="$BENCH_DIR"
    "$BENCH_DIR/config/generate_redis_configs.sh" > /dev/null 2>&1
    
    # Verify config file exists
    if [ ! -f "$BENCH_DIR/config/redis_cache.conf" ]; then
        log_error "Redis cache config file not found"
        exit 1
    fi
    
    # Use absolute path for config file to ensure Redis reads it correctly
    REDIS_CONFIG="$BENCH_DIR/config/redis_cache.conf"
    
    # Verify the config file has the correct port
    if ! grep -q "^port 13000" "$REDIS_CONFIG"; then
        log_error "Redis cache config file does not specify port 13000"
        log_info "Regenerating config..."
        "$BENCH_DIR/config/generate_redis_configs.sh"
    fi
    
    # Start Redis with the config file
    # Pass config file as first argument, then override port explicitly
    exec redis-server "$REDIS_CONFIG" --port 13000
}

# =============================================================================
# COMMAND: redis-queue - Start Redis queue
# =============================================================================
cmd_redis_queue() {
    log_info "Starting Redis queue..."
    
    # Ensure pids directory exists
    mkdir -p "$BENCH_DIR/config/pids"
    
    # Always regenerate Redis configs with current bench path before starting
    export FRAPPE_BENCH_ROOT="$BENCH_DIR"
    "$BENCH_DIR/config/generate_redis_configs.sh" > /dev/null 2>&1
    
    # Verify config file exists
    if [ ! -f "$BENCH_DIR/config/redis_queue.conf" ]; then
        log_error "Redis queue config file not found"
        exit 1
    fi
    
    # Use absolute path for config file to ensure Redis reads it correctly
    REDIS_CONFIG="$BENCH_DIR/config/redis_queue.conf"
    
    # Verify the config file has the correct port
    if ! grep -q "^port 11000" "$REDIS_CONFIG"; then
        log_error "Redis queue config file does not specify port 11000"
        log_info "Regenerating config..."
        "$BENCH_DIR/config/generate_redis_configs.sh"
    fi
    
    # Start Redis with the config file
    # Pass config file as first argument, then override port explicitly
    # This ensures our config is used and port is set correctly
    exec redis-server "$REDIS_CONFIG" --port 11000
}

# =============================================================================
# COMMAND: reinstall - Reinstall the site
# =============================================================================
cmd_reinstall() {
    echo "=== Reinstalling Site ==="
    echo ""
    
    log_info "This will reinstall the site and bootstrap the database."
    log_info "You will be prompted for the MariaDB root password."
    echo ""
    log_warning "If you don't know the root password, first reset it with:"
    echo "  sudo mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '';\""
    echo ""
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    
    activate_env
    
    # Try with empty password first
    log_info "Attempting reinstall with empty root password..."
    bench --site "$SITE_NAME" reinstall --yes --admin-password admin --db-root-username root --db-root-password "" || {
        log_warning "Reinstall with empty password failed"
        log_info "You'll need to run this manually in an interactive terminal:"
        echo "  bench --site $SITE_NAME reinstall --yes --admin-password admin"
        echo ""
        log_info "Then install the LMS app:"
        echo "  bench --site $SITE_NAME install-app lms"
        exit 1
    }
    
    log_success "Site reinstalled successfully!"
}

# =============================================================================
# COMMAND: fix-login - Fix login issues
# =============================================================================
cmd_fix_login() {
    echo "=== Fixing Login Issues ==="
    echo ""
    
    activate_env
    
    # 1. Ensure assets.json has frappe-web.bundle.js
    log_info "Updating assets.json..."
    python3 << PYEOF
import json
from pathlib import Path

sites_path = Path("sites")
assets_path = sites_path / "assets" / "assets.json"

if assets_path.exists():
    with open(assets_path) as f:
        assets = json.load(f)
    
    # Ensure frappe-web.bundle.js is mapped
    if "frappe-web.bundle.js" not in assets:
        assets["frappe-web.bundle.js"] = "/assets/frappe/dist/js/frappe-web.bundle.SZ7HXF36.js"
        print("   Added frappe-web.bundle.js mapping")
    
    with open(assets_path, 'w') as f:
        json.dump(assets, f, indent=2)
    
    print(f"   Updated assets.json ({len(assets)} entries)")
else:
    print("   assets.json not found, creating it...")
    assets_path.parent.mkdir(parents=True, exist_ok=True)
    assets = {
        "frappe-web.bundle.js": "/assets/frappe/dist/js/frappe-web.bundle.SZ7HXF36.js"
    }
    with open(assets_path, 'w') as f:
        json.dump(assets, f, indent=2)
    print(f"   Created assets.json")
PYEOF
    
    # 2. Clear all caches
    log_info "Clearing caches..."
    bench --site "$SITE_NAME" clear-cache 2>/dev/null || true
    log_success "Cache cleared"
    
    # 3. Verify Administrator password
    log_info "Checking Administrator user..."
    python3 << PYEOF
import frappe
frappe.init('$SITE_NAME')
frappe.connect()
try:
    user = frappe.get_doc("User", "Administrator")
    print(f"   User exists: {user.name}")
    print(f"   Enabled: {user.enabled}")
except Exception as e:
    print(f"   Error: {e}")
frappe.destroy()
PYEOF
    
    echo ""
    log_success "Login fix complete!"
    log_info "Test login:"
    echo "  1. Open ${SITE_HOST}"
    echo "  2. Username: Administrator"
    echo "  3. Password: admin (or the password you set)"
}

# =============================================================================
# COMMAND: sync-assets-json - Regenerate assets.json from existing built files
# =============================================================================
cmd_sync_assets_json() {
    echo "=== Syncing assets.json with Built Files ==="
    echo ""
    
    activate_env
    
    log_info "Regenerating assets.json from existing built files..."
    log_info "This will update assets.json to match the actual bundle files."
    echo ""
    
    # Use bench build with --using-cached to just update assets.json without rebuilding
    # This reads the existing built files and updates the JSON
    if ! bench build --using-cached > /dev/null 2>&1; then
        log_warning "Could not sync using cached build, trying to rebuild assets.json manually..."
        
        # Fallback: Use Python to directly update assets.json
        cd "$BENCH_DIR"
        python3 << 'PYEOF'
import json
import os
from pathlib import Path

sites_path = Path("sites")
assets_path = sites_path / "assets"
assets_json_path = assets_path / "assets.json"

assets = {}

# Find all bundle files in sites/assets
for app_dir in assets_path.iterdir():
    if app_dir.is_dir() and app_dir.name not in ["locale", "css", "js", "payments"]:
        dist_path = app_dir / "dist"
        if dist_path.exists():
            # Find JS bundles
            for js_file in dist_path.rglob("*.bundle.*.js"):
                rel_path = js_file.relative_to(assets_path)
                file_name = js_file.name
                
                # Extract key: e.g., "controls.bundle.js" from "controls.bundle.BD5FWKFH.js"
                # Pattern: name.bundle.hash.js (name can have dots/dashes/underscores)
                parts = file_name.split(".")
                if len(parts) >= 4 and "bundle" in parts:
                    # Find the index of "bundle"
                    bundle_idx = parts.index("bundle")
                    # Key is everything up to and including "bundle" + extension
                    # e.g., ["form", "builder", "bundle", "G3QQ3ZIB", "js"] -> "form.builder.bundle.js"
                    key_parts = parts[:bundle_idx + 1] + [parts[-1]]
                    key = ".".join(key_parts)
                    value = f"/assets/{rel_path.as_posix()}"
                    assets[key] = value
            
            # Find CSS bundles
            for css_file in dist_path.rglob("*.bundle.*.css"):
                rel_path = css_file.relative_to(assets_path)
                file_name = css_file.name
                
                parts = file_name.split(".")
                if len(parts) >= 4 and "bundle" in parts:
                    bundle_idx = parts.index("bundle")
                    key_parts = parts[:bundle_idx + 1] + [parts[-1]]
                    key = ".".join(key_parts)
                    value = f"/assets/{rel_path.as_posix()}"
                    assets[key] = value

# Write updated assets.json
assets_json_path.parent.mkdir(parents=True, exist_ok=True)
with open(assets_json_path, 'w') as f:
    json.dump(assets, f, indent=2, sort_keys=True)

print(f"   Updated assets.json with {len(assets)} entries")
PYEOF
        
        if [ $? -eq 0 ]; then
            log_success "assets.json regenerated successfully!"
        else
            log_error "Failed to regenerate assets.json"
            return 1
        fi
    else
        log_success "assets.json synced successfully!"
    fi
    
    # Clear cache
    log_info "Clearing cache..."
    bench --site "$SITE_NAME" clear-cache 2>/dev/null || true
    log_success "Cache cleared"
    
    echo ""
    log_success "Assets sync complete!"
}

# =============================================================================
# COMMAND: build-assets - Build all assets (JS and CSS bundles)
# =============================================================================
cmd_build_assets() {
    echo "=== Building Assets ==="
    echo ""
    
    activate_env
    
    log_info "Building all assets (this may take a few minutes)..."
    log_info "This will compile JavaScript and CSS bundles for all apps."
    echo ""
    
    # Build assets with force flag to ensure fresh build
    if bench build --force; then
        log_success "Assets built successfully!"
        
        # Ensure assets.json is updated
        log_info "Verifying assets.json is in sync..."
        bench build --using-cached > /dev/null 2>&1 || true
    else
        log_error "Asset build failed!"
        log_info "Try running manually: bench build --force"
        return 1
    fi
    
    # Clear cache after building
    log_info "Clearing cache..."
    bench --site "$SITE_NAME" clear-cache 2>/dev/null || true
    log_success "Cache cleared"
    
    echo ""
    log_success "Asset build complete!"
    log_info "Next steps:"
    echo "  1. Restart bench: $0 restart"
    echo "  2. Open ${SITE_HOST} in your browser"
    echo "  3. Press Ctrl+Shift+R (or Cmd+Shift+R on Mac) to hard refresh"
}

# =============================================================================
# COMMAND: fix-ui - Fix UI assets (syncs assets.json and clears cache)
# =============================================================================
cmd_fix_ui() {
    echo "=== Fixing UI Assets ==="
    echo ""
    
    activate_env
    
    # 1. First, try to sync assets.json with existing files (faster)
    log_info "Syncing assets.json with existing built files..."
    if bench build --using-cached > /dev/null 2>&1; then
        log_success "assets.json synced successfully"
    else
        log_warning "Could not sync with cached build, trying manual sync..."
        cmd_sync_assets_json
    fi
    
    # 2. If assets are missing, build them
    log_info "Checking if all required assets exist..."
    missing_assets=0
    if [ -f "sites/assets/assets.json" ]; then
        # Check a few critical bundles
        for bundle in "frappe-web.bundle.js" "libs.bundle.js" "controls.bundle.js" "desk.bundle.js"; do
            path=$(python3 -c "import json; f=open('sites/assets/assets.json'); d=json.load(f); print(d.get('$bundle', ''))" 2>/dev/null || echo "")
            if [ -n "$path" ]; then
                # Remove leading /assets/ to get relative path
                rel_path="${path#/assets/}"
                if [ ! -f "sites/assets/$rel_path" ]; then
                    log_warning "$bundle file not found at sites/assets/$rel_path"
                    missing_assets=1
                fi
            else
                log_warning "$bundle not found in assets.json"
                missing_assets=1
            fi
        done
    else
        log_warning "assets.json not found"
        missing_assets=1
    fi
    
    if [ $missing_assets -eq 1 ]; then
        log_info "Some assets are missing, building them..."
        if bench build --force; then
            log_success "Assets built successfully"
        else
            log_error "Asset build failed!"
            log_info "Try running: $0 build-assets"
            return 1
        fi
    else
        log_success "All required assets exist"
    fi
    
    # 3. Clear all caches
    log_info "Clearing caches..."
    bench --site "$SITE_NAME" clear-cache 2>/dev/null || true
    log_success "Cache cleared"
    
    echo ""
    log_success "UI assets fix complete!"
    log_info "Next steps:"
    echo "  1. Restart bench: $0 restart"
    echo "  2. Open ${SITE_HOST} in your browser"
    echo "  3. Press Ctrl+Shift+R (or Cmd+Shift+R on Mac) to hard refresh"
}

# =============================================================================
# COMMAND: verify-ui - Verify UI is working
# =============================================================================
cmd_verify_ui() {
    echo "=== Verifying UI Assets ==="
    echo ""
    
    log_info "Checking if bench is running..."
    if ! is_bench_running; then
        log_error "Bench is not running. Start it with: $0 start"
        exit 1
    fi
    log_success "Bench is running"
    
    echo ""
    log_info "Checking CSS files..."
    for css in "login.bundle.57LIKW7X.css" "website.bundle.6B52VKY7.css" "lms.bundle.VTQCHFW6.css"; do
        status=$(curl -s -o /dev/null -w "%{http_code}" "${SITE_HOST}/assets/frappe/dist/css/$css" 2>/dev/null || echo "000")
        if [ "$status" = "200" ]; then
            log_success "$css - OK (HTTP 200)"
        else
            log_warning "$css - Not found (HTTP $status)"
        fi
    done
    
    echo ""
    log_info "Checking assets.json..."
    if [ -f "sites/assets/assets.json" ]; then
        count=$(cat sites/assets/assets.json | grep -o '"[^"]*":' | wc -l | tr -d ' ')
        log_success "assets.json exists with $count entries"
    else
        log_warning "assets.json missing"
    fi
    
    echo ""
    log_info "Testing main page..."
    status=$(curl -s -o /dev/null -w "%{http_code}" "${SITE_HOST}" 2>/dev/null || echo "000")
    if [ "$status" = "200" ]; then
        log_success "Main page loads (HTTP 200)"
        
        echo ""
        log_info "Checking for CSS links in HTML..."
        css_count=$(curl -s "${SITE_HOST}" 2>/dev/null | grep -c "stylesheet" || echo "0")
        log_info "Found $css_count stylesheet links"
    else
        log_warning "Main page error (HTTP $status)"
    fi
    
    echo ""
    log_success "Verification complete!"
}

# =============================================================================
# MAIN - Command dispatcher
# =============================================================================
main() {
    case "${1:-help}" in
        check)
            cmd_check
            ;;
        fix-env)
            cmd_fix_env
            ;;
        fix-paths)
            cmd_fix_paths
            ;;
        setup-env)
            cmd_setup_env
            ;;
        find-paths)
            cmd_find_paths
            ;;
        stop)
            cmd_stop
            ;;
        start)
            cmd_start
            ;;
        restart)
            cmd_restart
            ;;
        status)
            cmd_status
            ;;
        redis-cache)
            cmd_redis_cache
            ;;
        redis-queue)
            cmd_redis_queue
            ;;
        reinstall)
            cmd_reinstall
            ;;
        fix-login)
            cmd_fix_login
            ;;
        build-assets)
            cmd_build_assets
            ;;
        sync-assets-json)
            cmd_sync_assets_json
            ;;
        fix-ui)
            cmd_fix_ui
            ;;
        verify-ui)
            cmd_verify_ui
            ;;
        help|--help|-h)
            echo "Bench Management Script"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  check         - Check setup and verify system"
            echo "  setup-env     - Setup environment configuration from .env file"
            echo "  fix-env       - Fix environment permissions and paths"
            echo "  fix-paths     - Make all paths dynamic and regenerate configs"
            echo "  find-paths    - Find hardcoded paths in the project"
            echo ""
            echo "  start         - Start bench"
            echo "  stop          - Stop all bench processes"
            echo "  restart       - Restart bench"
            echo "  status        - Check bench status"
            echo ""
            echo "  redis-cache   - Start Redis cache (for Procfile)"
            echo "  redis-queue   - Start Redis queue (for Procfile)"
            echo ""
            echo "  reinstall     - Reinstall the site"
            echo "  fix-login     - Fix login issues"
            echo "  build-assets  - Build all assets (JS and CSS bundles)"
            echo "  sync-assets-json - Regenerate assets.json from existing built files"
            echo "  fix-ui        - Fix UI assets (syncs assets.json and clears cache)"
            echo "  verify-ui     - Verify UI is working"
            echo ""
            echo "Environment Variables:"
            echo "  SITE_NAME     - Site name (default: vgi.local)"
            echo ""
            echo "Examples:"
            echo "  $0 check           # Check setup"
            echo "  $0 start           # Start bench"
            echo "  $0 build-assets    # Build all assets"
            echo "  $0 sync-assets-json # Sync assets.json with built files"
            echo "  $0 fix-ui          # Fix UI assets (recommended for 404 errors)"
            echo "  SITE_NAME=lms.localhost $0 reinstall  # Reinstall specific site"
            ;;
        *)
            log_error "Unknown command: $1"
            echo ""
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"

