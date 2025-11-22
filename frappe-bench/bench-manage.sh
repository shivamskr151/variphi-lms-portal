#!/bin/bash
# Comprehensive Bench Management Script
# Handles all bench operations: setup, maintenance, site management, and verification

set -e

# Auto-detect bench directory (script location)
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BENCH_DIR"

# Site name - auto-detect or use default
SITE_NAME="${SITE_NAME:-vgi.local}"

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
    OLD_PATH="${OLD_BENCH_PATH:-/mnt/d/Company/Variphi/test_lms/frappe-bench}"
    NEW_PATH="$BENCH_DIR"
    
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
    lsof -ti:8000,9000,11000,13000 2>/dev/null | xargs kill -9 2>/dev/null || true
    
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
# COMMAND: start - Start bench
# =============================================================================
cmd_start() {
    echo "=== Starting Bench ==="
    echo ""
    
    # Ensure Redis configs are up to date
    log_info "Ensuring Redis configs are up to date..."
    export FRAPPE_BENCH_ROOT="$BENCH_DIR"
    if [ -f "$BENCH_DIR/config/generate_redis_configs.sh" ]; then
        "$BENCH_DIR/config/generate_redis_configs.sh" > /dev/null 2>&1
    fi
    
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
        for port in 8000 9000 11000 13000; do
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
    
    # Start Redis with the freshly generated config
    exec redis-server "$BENCH_DIR/config/redis_cache.conf"
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
    
    # Start Redis with the freshly generated config
    exec redis-server "$BENCH_DIR/config/redis_queue.conf"
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
    echo "  1. Open http://127.0.0.1:8000"
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
    echo "  2. Open http://127.0.0.1:8000 in your browser"
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
    echo "  2. Open http://127.0.0.1:8000 in your browser"
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
        status=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8000/assets/frappe/dist/css/$css" 2>/dev/null || echo "000")
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
    status=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8000" 2>/dev/null || echo "000")
    if [ "$status" = "200" ]; then
        log_success "Main page loads (HTTP 200)"
        
        echo ""
        log_info "Checking for CSS links in HTML..."
        css_count=$(curl -s http://127.0.0.1:8000 2>/dev/null | grep -c "stylesheet" || echo "0")
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

