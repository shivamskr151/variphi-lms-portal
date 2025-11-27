#!/bin/bash
# Setup Environment Configuration Script
# Reads .env file and generates all necessary configuration files

set -e

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BENCH_DIR"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

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

# Check if .env file exists
ENV_FILE="$BENCH_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    log_warning ".env file not found. Creating from .env.example..."
    if [ -f "$BENCH_DIR/.env.example" ]; then
        cp "$BENCH_DIR/.env.example" "$ENV_FILE"
        log_info "Created .env file from .env.example"
        log_warning "Please edit .env file with your configuration before continuing"
        log_info "You can run this script again after editing .env"
        exit 0
    else
        log_error ".env.example not found. Cannot create .env file."
        exit 1
    fi
fi

# Load environment variables from .env file
log_info "Loading environment variables from .env..."
set -a
source "$ENV_FILE"
set +a

# Generate random values if not set
generate_random_string() {
    openssl rand -hex 16 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(16))" 2>/dev/null || echo "$(date +%s | sha256sum | base64 | head -c 32)"
}

# Auto-generate database credentials if not set
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    log_info "Auto-generating database credentials..."
    DB_NAME="_$(openssl rand -hex 8 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(8))" 2>/dev/null || echo "$(date +%s | sha256sum | base64 | head -c 16)")"
    DB_USER="$DB_NAME"
    DB_PASSWORD="$(generate_random_string)"
    
    # Update .env file with generated values
    if grep -q "^DB_NAME=" "$ENV_FILE"; then
        sed -i.bak "s|^DB_NAME=.*|DB_NAME=$DB_NAME|" "$ENV_FILE"
    else
        echo "DB_NAME=$DB_NAME" >> "$ENV_FILE"
    fi
    
    if grep -q "^DB_USER=" "$ENV_FILE"; then
        sed -i.bak "s|^DB_USER=.*|DB_USER=$DB_USER|" "$ENV_FILE"
    else
        echo "DB_USER=$DB_USER" >> "$ENV_FILE"
    fi
    
    if grep -q "^DB_PASSWORD=" "$ENV_FILE"; then
        sed -i.bak "s|^DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" "$ENV_FILE"
    else
        echo "DB_PASSWORD=$DB_PASSWORD" >> "$ENV_FILE"
    fi
    
    rm -f "$ENV_FILE.bak" 2>/dev/null || true
    log_success "Generated database credentials: $DB_NAME"
fi

# Auto-generate encryption key if not set
if [ -z "$ENCRYPTION_KEY" ]; then
    log_info "Auto-generating encryption key..."
    ENCRYPTION_KEY="$(openssl rand -base64 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_urlsafe(32))" 2>/dev/null || echo "$(date +%s | sha256sum | base64 | head -c 44)=")"
    
    if grep -q "^ENCRYPTION_KEY=" "$ENV_FILE"; then
        sed -i.bak "s|^ENCRYPTION_KEY=.*|ENCRYPTION_KEY=$ENCRYPTION_KEY|" "$ENV_FILE"
    else
        echo "ENCRYPTION_KEY=$ENCRYPTION_KEY" >> "$ENV_FILE"
    fi
    
    rm -f "$ENV_FILE.bak" 2>/dev/null || true
fi

# Auto-detect FRAPPE_USER if not set
if [ -z "$FRAPPE_USER" ]; then
    FRAPPE_USER=$(whoami)
    if grep -q "^FRAPPE_USER=" "$ENV_FILE"; then
        sed -i.bak "s|^FRAPPE_USER=.*|FRAPPE_USER=$FRAPPE_USER|" "$ENV_FILE"
    else
        echo "FRAPPE_USER=$FRAPPE_USER" >> "$ENV_FILE"
    fi
    rm -f "$ENV_FILE.bak" 2>/dev/null || true
    log_info "Auto-detected FRAPPE_USER: $FRAPPE_USER"
fi

# Set defaults
SITE_NAME="${SITE_NAME:-vgi.local}"
SITE_HOST="${SITE_HOST:-http://127.0.0.1:8000}"
APP_NAME="${APP_NAME:-VariPhi}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_TYPE="${DB_TYPE:-mariadb}"
WEBSERVER_PORT="${WEBSERVER_PORT:-8000}"
SOCKETIO_PORT="${SOCKETIO_PORT:-9000}"
FILE_WATCHER_PORT="${FILE_WATCHER_PORT:-6787}"
GUNICORN_WORKERS="${GUNICORN_WORKERS:-9}"
BACKGROUND_WORKERS="${BACKGROUND_WORKERS:-1}"
DEVELOPER_MODE="${DEVELOPER_MODE:-1}"
LIVE_RELOAD="${LIVE_RELOAD:-true}"
SERVE_DEFAULT_SITE="${SERVE_DEFAULT_SITE:-true}"
DOCKER_MODE="${DOCKER_MODE:-false}"

# Detect if running in Docker
if [ "$DOCKER_MODE" = "true" ] || [ -f "/.dockerenv" ]; then
    log_info "Docker mode detected"
    if [ "$DB_HOST" = "127.0.0.1" ]; then
        DB_HOST="host.docker.internal"
        log_info "Updated DB_HOST to host.docker.internal for Docker"
    fi
    if [[ "$REDIS_CACHE" == redis://127.0.0.1* ]] || [[ "$REDIS_CACHE" == redis://localhost* ]]; then
        REDIS_CACHE="redis://redis:6379"
        REDIS_QUEUE="redis://redis:6379"
        REDIS_SOCKETIO="redis://redis:6379"
        log_info "Updated Redis URLs for Docker"
    fi
fi

# Generate common_site_config.json
log_info "Generating common_site_config.json..."
cat > "$BENCH_DIR/sites/common_site_config.json" << EOF
{
 "background_workers": ${BACKGROUND_WORKERS},
 "default_site": "${SITE_NAME}",
 "file_watcher_port": ${FILE_WATCHER_PORT},
 "frappe_user": "${FRAPPE_USER}",
 "gunicorn_workers": ${GUNICORN_WORKERS},
 "live_reload": ${LIVE_RELOAD},
 "mariadb_root_password": "${MARIADB_ROOT_PASSWORD}",
 "rebase_on_pull": false,
 "redis_cache": "${REDIS_CACHE}",
 "redis_queue": "${REDIS_QUEUE}",
 "redis_socketio": "${REDIS_SOCKETIO}",
 "restart_supervisor_on_update": false,
 "restart_systemd_on_update": false,
 "serve_default_site": ${SERVE_DEFAULT_SITE},
 "shallow_clone": true,
 "socketio_port": ${SOCKETIO_PORT},
 "use_redis_auth": false,
 "webserver_port": ${WEBSERVER_PORT}
}
EOF
log_success "Generated common_site_config.json"

# Generate site_config.json if site directory exists
SITE_DIR="$BENCH_DIR/sites/$SITE_NAME"
if [ -d "$SITE_DIR" ]; then
    log_info "Generating site_config.json for $SITE_NAME..."
    cat > "$SITE_DIR/site_config.json" << EOF
{
 "app_name": "${APP_NAME}",
 "db_host": "${DB_HOST}",
 "db_name": "${DB_NAME}",
 "db_password": "${DB_PASSWORD}",
 "db_port": ${DB_PORT},
 "db_type": "${DB_TYPE}",
 "db_user": "${DB_USER}",
 "developer_mode": ${DEVELOPER_MODE},
 "disable_signup": 0,
 "encryption_key": "${ENCRYPTION_KEY}",
 "host_name": "${SITE_HOST}",
 "installed_apps": "[\"frappe\",\"lms\"]"
}
EOF
    log_success "Generated site_config.json"
else
    log_warning "Site directory $SITE_DIR not found. site_config.json will be created when site is initialized."
fi

# Generate database setup SQL
log_info "Generating create_db_user.sql..."
cat > "$BENCH_DIR/create_db_user.sql" << EOF
-- Create database user and database for Frappe site
-- Auto-generated from .env configuration
-- Run this with: mysql -u root -p < create_db_user.sql
-- OR: sudo mysql < create_db_user.sql

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
log_success "Generated create_db_user.sql"

# Regenerate Redis configs
log_info "Regenerating Redis configuration files..."
export FRAPPE_BENCH_ROOT="$BENCH_DIR"
if [ -f "$BENCH_DIR/config/generate_redis_configs.sh" ]; then
    "$BENCH_DIR/config/generate_redis_configs.sh"
    log_success "Redis configs regenerated"
fi

log_success "Environment setup complete!"
echo ""
log_info "Next steps:"
echo "  1. Review the generated configuration files"
echo "  2. Set up database: mysql -u root${MARIADB_ROOT_PASSWORD:+-p} < create_db_user.sql"
echo "  3. Run: ./bench-manage.sh start"

