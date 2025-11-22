#!/bin/bash
# Setup Dependencies Script
# Ensures all dependencies are installed and cached for reproducible builds
# Can be run locally or in Docker

set -e

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BENCH_DIR"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Activate virtual environment
if [ -f "$BENCH_DIR/env/bin/activate" ]; then
    source "$BENCH_DIR/env/bin/activate"
else
    log_warning "Virtual environment not found, creating it..."
    python3 -m venv "$BENCH_DIR/env"
    source "$BENCH_DIR/env/bin/activate"
fi

log_info "Setting up Python dependencies..."
cd "$BENCH_DIR"

# Install/upgrade bench requirements
if [ -f "requirements.txt" ]; then
    pip install --upgrade -r requirements.txt || true
fi

# Setup bench requirements
if command -v bench >/dev/null 2>&1; then
    log_info "Installing bench requirements..."
    bench setup requirements || {
        log_warning "bench setup requirements had issues, but continuing..."
    }
else
    log_warning "bench command not found, skipping bench setup"
fi

# Install Python app dependencies
log_info "Installing Python app dependencies..."
for app_dir in apps/*/; do
    app_name=$(basename "$app_dir")
    if [ -f "$app_dir/pyproject.toml" ] || [ -f "$app_dir/setup.py" ]; then
        log_info "Installing $app_name Python dependencies..."
        pip install --upgrade -e "$app_dir" || {
            log_warning "Failed to install $app_name Python dependencies"
        }
    fi
done

# Install Node.js dependencies
log_info "Setting up Node.js dependencies..."

# Check for Node.js
if ! command -v node >/dev/null 2>&1; then
    log_warning "Node.js not found, skipping Node.js dependencies"
    exit 0
fi

# Install dependencies for each app with package.json
for app_dir in apps/*/; do
    app_name=$(basename "$app_dir")
    if [ -f "$app_dir/package.json" ]; then
        log_info "Installing $app_name Node.js dependencies..."
        cd "$app_dir"
        
        # Use yarn if yarn.lock exists, otherwise npm
        if [ -f "yarn.lock" ]; then
            if command -v yarn >/dev/null 2>&1; then
                yarn install --frozen-lockfile || {
                    log_warning "yarn install failed for $app_name, trying without frozen lockfile..."
                    yarn install || log_warning "yarn install failed for $app_name"
                }
            else
                log_warning "yarn not found, skipping $app_name"
            fi
        elif [ -f "package-lock.json" ]; then
            if command -v npm >/dev/null 2>&1; then
                npm ci || {
                    log_warning "npm ci failed for $app_name, trying npm install..."
                    npm install || log_warning "npm install failed for $app_name"
                }
            else
                log_warning "npm not found, skipping $app_name"
            fi
        else
            if command -v yarn >/dev/null 2>&1; then
                yarn install || log_warning "yarn install failed for $app_name"
            elif command -v npm >/dev/null 2>&1; then
                npm install || log_warning "npm install failed for $app_name"
            fi
        fi
        
        cd "$BENCH_DIR"
    fi
done

log_success "Dependencies setup complete!"

