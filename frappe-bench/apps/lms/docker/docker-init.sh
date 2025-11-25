#!/bin/bash
# Simplified initialization script for Docker setup
# This script sets up the bench and site on first run

set -e

BENCH_DIR="/home/frappe/frappe-bench"
cd "$BENCH_DIR" || exit 1

# Set environment variables early
export FRAPPE_BENCH_ROOT="$BENCH_DIR"

echo "🚀 Initializing Frappe Bench in Docker..."

# Function to wait for MariaDB
wait_for_mariadb() {
    echo "⏳ Waiting for MariaDB to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if mysql -h "${MARIADB_HOST:-mariadb}" -u root -p"${MARIADB_ROOT_PASSWORD:-123}" -e "SELECT 1" >/dev/null 2>&1; then
            echo "✅ MariaDB is ready"
            return 0
        fi
        echo "   Attempt $attempt/$max_attempts: Waiting for MariaDB..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "⚠️  MariaDB did not become ready, continuing anyway..."
    return 1
}

# Wait for database
wait_for_mariadb || true

# Verify bench structure exists
if [ ! -d "apps/frappe" ]; then
    echo "❌ Error: Frappe app not found! The source code may not have been copied correctly."
    exit 1
fi

echo "✅ Bench structure verified"

# Setup Python environment if it doesn't exist
if [ ! -d "env" ] || [ ! -f "env/bin/python" ] || [ ! -f "env/bin/python3" ]; then
    echo "🐍 Setting up Python virtual environment..."
    
    # Find available Python
    PYTHON_CMD=""
    for py in python3.13 python3.12 python3.11 python3.10 python3; do
        if command -v "$py" >/dev/null 2>&1; then
            PYTHON_CMD=$(command -v "$py")
            PYTHON_VERSION=$("$PYTHON_CMD" --version 2>&1)
            echo "   Using Python: $PYTHON_CMD ($PYTHON_VERSION)"
            break
        fi
    done
    
    if [ -z "$PYTHON_CMD" ]; then
        echo "❌ Error: No Python interpreter found!"
        exit 1
    fi
    
    # Remove existing env if it's broken (but not if it's working)
    if [ -d "env" ] && [ ! -f "env/bin/python" ] && [ ! -f "env/bin/python3" ] && [ ! -f "env/bin/activate" ]; then
        echo "   Removing broken virtual environment..."
        rm -rf env
    fi
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "env" ]; then
        echo "   Creating new virtual environment..."
        "$PYTHON_CMD" -m venv env || {
            echo "   ⚠️  Venv creation failed, will try bench setup..."
        }
    fi
    
    # Setup virtual environment using bench setup requirements (recommended way)
    echo "   Setting up virtual environment via bench setup requirements..."
    # Activate env first if it exists
    if [ -f "env/bin/activate" ]; then
        source env/bin/activate
        export PATH="$(pwd)/env/bin:$PATH"
    fi
    
    # Run bench setup requirements to install all dependencies
    if ! bench setup requirements 2>&1; then
        echo "   ⚠️  Bench setup had issues, but continuing..."
    fi
fi

# Ensure we're using the bench virtual environment
if [ -f "env/bin/activate" ]; then
    source env/bin/activate
    export PATH="$(pwd)/env/bin:$PATH"
    export VIRTUAL_ENV="$(pwd)/env"
    
    # Verify Python exists and works
    if [ -f "env/bin/python" ]; then
        PYTHON_EXE="$(pwd)/env/bin/python"
    elif [ -f "env/bin/python3" ]; then
        PYTHON_EXE="$(pwd)/env/bin/python3"
        ln -sf python3 env/bin/python 2>/dev/null || true
    else
        echo "❌ Error: No Python executable found in virtual environment!"
        exit 1
    fi
    
    echo "✅ Virtual environment activated: $PYTHON_EXE"
    
    # Verify Python is working
    if ! "$PYTHON_EXE" -c "import sys; print(sys.executable)" >/dev/null 2>&1; then
        echo "❌ Error: Python interpreter not working correctly!"
        exit 1
    fi
else
    echo "❌ Error: Virtual environment activation script not found!"
    exit 1
fi

# Install Python app dependencies (including frappe - needed for bench commands)
echo "📦 Installing Python app dependencies..."
for app in apps/*/; do
    if [ -f "$app/pyproject.toml" ] || [ -f "$app/setup.py" ]; then
        app_name=$(basename "$app")
        
        echo "   Installing $app_name..."
        
        # Ensure README.md exists if pyproject.toml references it
        if [ -f "$app/pyproject.toml" ] && grep -q "readme.*README.md" "$app/pyproject.toml"; then
            if [ ! -f "$app/README.md" ]; then
                echo "      Creating placeholder README.md for $app_name..."
                echo "# $app_name" > "$app/README.md"
            fi
        fi
        
        # Install in editable mode - frappe is critical, others can fail gracefully
        set +e
        if pip install -e "$app" >/tmp/pip-install-$app_name.log 2>&1; then
            echo "      ✅ $app_name installed successfully"
        else
            # Check error log for specific issues
            if grep -q "README.md does not exist" /tmp/pip-install-$app_name.log 2>/dev/null; then
                echo "      ⚠️  README.md issue, creating placeholder and retrying..."
                echo "# $app_name" > "$app/README.md"
                pip install -e "$app" >/tmp/pip-install-$app_name.log 2>&1 && \
                    echo "      ✅ $app_name installed after creating README.md" || \
                    echo "      ⚠️  Installation still failed for $app_name"
            elif pip show "$app_name" >/dev/null 2>&1; then
                echo "      ✅ $app_name is already installed"
            else
                echo "      ⚠️  Installation failed for $app_name, but continuing..."
            fi
        fi
        set -e
    fi
done

# Install Node.js dependencies with retry logic for network issues
echo "📦 Installing Node.js dependencies..."
for app in apps/*/; do
    if [ -f "$app/package.json" ]; then
        app_name=$(basename "$app")
        echo "   Installing $app_name Node.js dependencies..."
        cd "$app"
        
        # Retry logic for network issues
        MAX_RETRIES=3
        RETRY_DELAY=5
        attempt=1
        success=false
        
        while [ $attempt -le $MAX_RETRIES ] && [ "$success" = false ]; do
            if [ -f "yarn.lock" ]; then
                if yarn install --frozen-lockfile --network-timeout 600000 2>&1 | tee /tmp/yarn-install.log; then
                    success=true
                elif [ $attempt -lt $MAX_RETRIES ]; then
                    echo "      ⚠️  Network issue detected, retrying in ${RETRY_DELAY}s (attempt $attempt/$MAX_RETRIES)..."
                    sleep $RETRY_DELAY
                    RETRY_DELAY=$((RETRY_DELAY * 2))
                else
                    echo "      ⚠️  Trying without frozen lockfile..."
                    yarn install --network-timeout 600000 || true
                fi
            elif [ -f "package-lock.json" ]; then
                if npm ci --prefer-offline --no-audit 2>&1 | tee /tmp/npm-install.log; then
                    success=true
                elif [ $attempt -lt $MAX_RETRIES ]; then
                    echo "      ⚠️  Network issue detected, retrying in ${RETRY_DELAY}s (attempt $attempt/$MAX_RETRIES)..."
                    sleep $RETRY_DELAY
                    RETRY_DELAY=$((RETRY_DELAY * 2))
                else
                    echo "      ⚠️  Trying npm install instead..."
                    npm install --prefer-offline --no-audit || true
                fi
            else
                npm install --prefer-offline --no-audit || yarn install --network-timeout 600000 || true
                success=true  # Don't retry if no lock file
            fi
            attempt=$((attempt + 1))
        done
        
        cd /home/frappe/frappe-bench
    fi
done

# Verify apps exist (they should be copied or mounted)
if [ ! -d "apps/lms" ]; then
    echo "⚠️  LMS app not found in apps/lms"
    echo "   Make sure the source code is properly mounted or copied"
fi

if [ ! -d "apps/payments" ]; then
    echo "⚠️  Payments app not found in apps/payments"
fi

# Update Redis configuration to use external Redis container
echo "🔧 Updating Redis configuration for Docker..."
if [ -f "sites/common_site_config.json" ]; then
    # Use Python from virtual environment to update JSON config
    PYTHON_CMD="$PYTHON_EXE"
    if [ ! -f "$PYTHON_CMD" ] || ! "$PYTHON_CMD" --version >/dev/null 2>&1; then
        PYTHON_CMD=python3
    fi
    
    "$PYTHON_CMD" << 'PYTHON_SCRIPT' 2>/dev/null || true
import json
import os

config_file = "sites/common_site_config.json"
if os.path.exists(config_file):
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
        
        config['redis_cache'] = 'redis://redis:6379'
        config['redis_queue'] = 'redis://redis:6379'
        config['redis_socketio'] = 'redis://redis:6379'
        
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=1)
        print("✅ Updated Redis configuration")
    except Exception as e:
        print(f"⚠️  Could not update Redis config: {e}")
PYTHON_SCRIPT
fi

# Setup site if it doesn't exist OR if database connection fails
SITE_NAME="${SITE_NAME:-vgi.local}"
SITE_EXISTS=false
DB_CONNECTION_WORKS=false

if [ -d "sites/$SITE_NAME" ]; then
    SITE_EXISTS=true
    echo "🌐 Site $SITE_NAME already exists, checking database connection..."
    
    # Test database connection
    export PATH="$(pwd)/env/bin:$PATH"
    export VIRTUAL_ENV="$(pwd)/env"
    export FRAPPE_BENCH_ROOT="$(pwd)"
    export FRAPPE_DB_HOST="${MARIADB_HOST:-mariadb}"
    export FRAPPE_DB_PORT="3306"
    export FRAPPE_DB_SOCKET=""
    
    # Try to connect to database
    if bench --site "$SITE_NAME" list-apps >/dev/null 2>&1; then
        DB_CONNECTION_WORKS=true
        echo "✅ Database connection working"
    else
        echo "⚠️  Database connection failed, site may need to be recreated"
        # Remove site directory to force recreation
        echo "   Removing existing site directory to recreate with Docker database..."
        rm -rf "sites/$SITE_NAME"
        SITE_EXISTS=false
    fi
fi

if [ "$SITE_EXISTS" = false ]; then
    echo "🌐 Creating site: $SITE_NAME"
    
    # Ensure environment variables are set for bench
    export PATH="$(pwd)/env/bin:$PATH"
    export VIRTUAL_ENV="$(pwd)/env"
    export FRAPPE_BENCH_ROOT="$(pwd)"
    
    # Set database environment variables to ensure TCP connection
    export FRAPPE_DB_HOST="${MARIADB_HOST:-mariadb}"
    export FRAPPE_DB_PORT="3306"
    export FRAPPE_DB_SOCKET=""
    
    # Create site with explicit TCP connection (not socket)
    bench new-site "$SITE_NAME" \
        --db-host "${MARIADB_HOST:-mariadb}" \
        --db-port 3306 \
        --mariadb-root-password "${MARIADB_ROOT_PASSWORD:-123}" \
        --admin-password "${ADMIN_PASSWORD:-admin}" \
        --no-mariadb-socket || {
        echo "⚠️  Site creation had issues, but continuing..."
    }
fi

# Always ensure site configuration uses TCP connection to mariadb container (fix existing sites too)
if [ -d "sites/$SITE_NAME" ] && [ -f "sites/$SITE_NAME/site_config.json" ]; then
    echo "🔧 Updating site database configuration for Docker..."
    SITE_NAME_VALUE="$SITE_NAME" MARIADB_HOST_VALUE="${MARIADB_HOST:-mariadb}" "$PYTHON_EXE" -c "
import json
import os

site_name = os.environ['SITE_NAME_VALUE']
mariadb_host = os.environ['MARIADB_HOST_VALUE']
config_file = f'sites/{site_name}/site_config.json'

try:
    if os.path.exists(config_file):
        with open(config_file, 'r') as f:
            config = json.load(f)
        
        old_host = config.get('db_host', 'localhost')
        
        # Force TCP connection (no socket) to Docker mariadb container
        config['db_host'] = mariadb_host
        config['db_port'] = 3306
        # Remove socket setting if it exists
        if 'db_socket' in config:
            del config['db_socket']
        
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=1)
        
        if old_host != mariadb_host:
            print(f'✅ Updated site database configuration from {old_host} to TCP: {mariadb_host}:3306')
        else:
            print(f'✅ Verified site database configuration uses TCP: {mariadb_host}:3306')
    else:
        print(f'⚠️  Site config file not found: {config_file}')
except Exception as e:
    print(f'⚠️  Could not update site config: {e}')
" 2>&1 || echo "⚠️  Could not update site config"
fi

# Install apps on site
if [ -d "sites/$SITE_NAME" ]; then
    echo "📦 Installing apps on site..."
    
    # Ensure environment is set
    export PATH="$(pwd)/env/bin:$PATH"
    export VIRTUAL_ENV="$(pwd)/env"
    export FRAPPE_BENCH_ROOT="$(pwd)"
    
    # Set database environment variables to ensure TCP connection
    export FRAPPE_DB_HOST="${MARIADB_HOST:-mariadb}"
    export FRAPPE_DB_PORT="3306"
    export FRAPPE_DB_SOCKET=""
    
    # Install LMS app
    if bench --site "$SITE_NAME" list-apps 2>/dev/null | grep -q lms; then
        echo "✅ LMS app already installed"
    else
        echo "   Installing LMS app..."
        bench --site "$SITE_NAME" install-app lms 2>&1 || {
            echo "⚠️  Failed to install LMS app (may need to be done manually)"
        }
    fi
    
    # Install Payments app
    if bench --site "$SITE_NAME" list-apps 2>/dev/null | grep -q payments; then
        echo "✅ Payments app already installed"
    else
        echo "   Installing Payments app..."
        bench --site "$SITE_NAME" install-app payments 2>&1 || {
            echo "⚠️  Failed to install Payments app (may need to be done manually)"
        }
    fi
    
    # Enable signup
    bench --site "$SITE_NAME" set-config disable_signup 0 2>&1 || true
    bench --site "$SITE_NAME" set-config app_name "VariPhi" 2>&1 || true
    bench --site "$SITE_NAME" clear-cache 2>&1 || true
fi

# Build assets
echo "🎨 Building assets..."
export PATH="$(pwd)/env/bin:$PATH"
export VIRTUAL_ENV="$(pwd)/env"
export FRAPPE_BENCH_ROOT="$(pwd)"

bench build --app lms 2>&1 || {
    echo "⚠️  Asset build had issues, but continuing..."
}

echo "✅ Initialization complete!"
echo "🚀 Starting Frappe Bench..."

# Verify bench can find frappe and Python
echo "🔍 Verifying bench configuration..."
if ! "$PYTHON_EXE" -c "import frappe" 2>/dev/null; then
    echo "⚠️  Warning: Frappe module not importable in virtual environment"
    echo "   This may cause issues with bench commands"
fi

# Ensure all environment variables are set for bench processes
export PATH="$(pwd)/env/bin:$PATH"
export VIRTUAL_ENV="$(pwd)/env"
export FRAPPE_BENCH_ROOT="$(pwd)"

# Start bench (Redis processes are commented out in Procfile - using external Redis container)
# Use exec to replace shell process
exec bench start

