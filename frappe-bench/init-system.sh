#!/bin/bash
# System Initialization Script
# Sets up the project on a new system with minimal conflicts

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

echo "=========================================="
echo "  VariPhi LMS - System Initialization"
echo "=========================================="
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

# Check Python
if ! command -v python3 &> /dev/null; then
    log_error "Python 3 is required but not installed"
    exit 1
fi
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
log_success "Python $PYTHON_VERSION found"

# Check Node.js
if ! command -v node &> /dev/null; then
    log_error "Node.js is required but not installed"
    exit 1
fi
NODE_VERSION=$(node --version)
log_success "Node.js $NODE_VERSION found"

# Check Yarn
if ! command -v yarn &> /dev/null; then
    log_warning "Yarn not found, will use npm"
    USE_YARN=false
else
    log_success "Yarn found"
    USE_YARN=true
fi

# Check MariaDB/MySQL
if ! command -v mysql &> /dev/null; then
    log_warning "MySQL/MariaDB client not found. Database setup will be skipped."
    SKIP_DB=true
else
    log_success "MySQL/MariaDB client found"
    SKIP_DB=false
fi

# Check Redis (optional)
if ! command -v redis-server &> /dev/null; then
    log_warning "Redis server not found. Redis will need to be installed separately."
else
    log_success "Redis server found"
fi

echo ""

# Step 1: Setup environment
log_info "Step 1: Setting up environment configuration..."
if [ -f "$BENCH_DIR/setup-env.sh" ]; then
    chmod +x "$BENCH_DIR/setup-env.sh"
    "$BENCH_DIR/setup-env.sh"
    log_success "Environment configured"
else
    log_error "setup-env.sh not found"
    exit 1
fi

echo ""

# Step 2: Load environment variables
log_info "Step 2: Loading environment variables..."
if [ -f "$BENCH_DIR/.env" ]; then
    set -a
    source "$BENCH_DIR/.env"
    set +a
    log_success "Environment variables loaded"
else
    log_error ".env file not found. Please run setup-env.sh first."
    exit 1
fi

echo ""

# Step 3: Setup virtual environment
log_info "Step 3: Setting up Python virtual environment..."
if [ ! -d "$BENCH_DIR/env" ]; then
    python3 -m venv "$BENCH_DIR/env"
    log_success "Virtual environment created"
else
    log_info "Virtual environment already exists"
fi

# Activate virtual environment
source "$BENCH_DIR/env/bin/activate"
log_success "Virtual environment activated"

echo ""

# Step 4: Install Python dependencies
log_info "Step 4: Installing Python dependencies..."
if [ -f "$BENCH_DIR/setup-dependencies.sh" ]; then
    chmod +x "$BENCH_DIR/setup-dependencies.sh"
    "$BENCH_DIR/setup-dependencies.sh"
    log_success "Python dependencies installed"
else
    log_warning "setup-dependencies.sh not found, installing manually..."
    pip install --upgrade pip setuptools wheel
    if command -v bench &> /dev/null; then
        bench setup requirements || log_warning "bench setup requirements had issues"
    fi
    for app_dir in apps/*/; do
        if [ -f "$app_dir/pyproject.toml" ] || [ -f "$app_dir/setup.py" ]; then
            pip install --upgrade -e "$app_dir" || log_warning "Failed to install $(basename $app_dir)"
        fi
    done
fi

echo ""

# Step 5: Install Node.js dependencies
log_info "Step 5: Installing Node.js dependencies..."
for app_dir in apps/*/; do
    if [ -f "$app_dir/package.json" ]; then
        app_name=$(basename "$app_dir")
        log_info "Installing dependencies for $app_name..."
        cd "$app_dir"
        if [ "$USE_YARN" = true ] && [ -f "yarn.lock" ]; then
            yarn install --frozen-lockfile || yarn install
        elif [ -f "package-lock.json" ]; then
            npm ci || npm install
        else
            if [ "$USE_YARN" = true ]; then
                yarn install
            else
                npm install
            fi
        fi
        cd "$BENCH_DIR"
    fi
done
log_success "Node.js dependencies installed"

echo ""

# Step 6: Setup database
if [ "$SKIP_DB" = false ]; then
    log_info "Step 6: Setting up database..."
    if [ -f "$BENCH_DIR/create_db_user.sql" ]; then
        log_info "Creating database user and database..."
        if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
            mysql -u root < "$BENCH_DIR/create_db_user.sql" 2>/dev/null || {
                log_warning "Failed to create database with root user (no password)"
                log_info "Trying with sudo..."
                sudo mysql < "$BENCH_DIR/create_db_user.sql" || {
                    log_warning "Database setup failed. You can run manually:"
                    echo "  mysql -u root -p < create_db_user.sql"
                }
            }
        else
            mysql -u root -p"$MARIADB_ROOT_PASSWORD" < "$BENCH_DIR/create_db_user.sql" || {
                log_warning "Database setup failed. You can run manually:"
                echo "  mysql -u root -p < create_db_user.sql"
            }
        fi
        log_success "Database setup attempted"
    else
        log_warning "create_db_user.sql not found. Database setup skipped."
    fi
else
    log_warning "Step 6: Database setup skipped (MySQL client not found)"
fi

echo ""

# Step 7: Fix paths
log_info "Step 7: Fixing paths and configurations..."
if [ -f "$BENCH_DIR/bench-manage.sh" ]; then
    chmod +x "$BENCH_DIR/bench-manage.sh"
    "$BENCH_DIR/bench-manage.sh" fix-paths || log_warning "Path fixing had issues"
    log_success "Paths fixed"
fi

echo ""

# Step 8: Build assets (if site exists)
SITE_DIR="$BENCH_DIR/sites/$SITE_NAME"
if [ -d "$SITE_DIR" ] && command -v bench &> /dev/null; then
    log_info "Step 8: Building assets..."
    bench build --app frappe || log_warning "Asset build had issues"
    bench build --app lms || log_warning "LMS asset build had issues"
    log_success "Assets built"
else
    log_warning "Step 8: Asset build skipped (site not found or bench not available)"
fi

echo ""
echo "=========================================="
log_success "System initialization complete!"
echo "=========================================="
echo ""
log_info "Next steps:"
echo ""
echo "  1. If database was not set up, run:"
echo "     mysql -u root -p < create_db_user.sql"
echo ""
echo "  2. If site doesn't exist, create it:"
echo "     bench new-site $SITE_NAME"
echo ""
echo "  3. Install apps:"
echo "     bench --site $SITE_NAME install-app lms"
echo ""
echo "  4. Start the server:"
echo "     ./bench-manage.sh start"
echo ""
echo "  5. Access the application:"
echo "     $SITE_HOST"
echo ""

