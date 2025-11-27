#!/bin/bash
# Simplified initialization script for Docker setup
# This script sets up the bench and site on first run

set -e

BENCH_DIR="/home/frappe/frappe-bench"
cd "$BENCH_DIR" || exit 1

# Set environment variables early
export FRAPPE_BENCH_ROOT="$BENCH_DIR"

# Load .env file if it exists (mounted from host)
echo "📋 Loading environment variables from .env file..."
if [ -f "$BENCH_DIR/.env" ]; then
    set -a
    source "$BENCH_DIR/.env"
    set +a
    echo "✅ Loaded .env file"
else
    echo "⚠️  .env file not found, using environment variables from docker-compose"
fi

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

# Override DB_HOST for Docker - use host.docker.internal to connect to local MariaDB
# This is critical for Docker containers to access the host's MariaDB
if [ -z "$FRAPPE_DB_HOST" ] || [ "$FRAPPE_DB_HOST" = "127.0.0.1" ] || [ "$FRAPPE_DB_HOST" = "localhost" ]; then
    export FRAPPE_DB_HOST="${MARIADB_HOST:-host.docker.internal}"
    echo "🔧 Updated FRAPPE_DB_HOST to $FRAPPE_DB_HOST for Docker"
fi

echo "🚀 Initializing Frappe Bench in Docker..."

# Function to wait for MariaDB (local or Docker)
wait_for_mariadb() {
    local db_host="${FRAPPE_DB_HOST:-${MARIADB_HOST:-host.docker.internal}}"
    local db_port="${FRAPPE_DB_PORT:-${DB_PORT:-3306}}"
    local db_root_password="${MARIADB_ROOT_PASSWORD:-}"
    
    echo "⏳ Checking MariaDB connection at $db_host:$db_port..."
    
    # Use Python to check database connection (more reliable than mysql client)
    # This works even if mysql client is not installed in the container
    local max_attempts=15
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # Try to connect using Python (which is always available in the container)
        if python3 << PYEOF 2>/dev/null; then
import socket
import sys

host = "$db_host"
port = int("$db_port")

try:
    # First check if we can reach the host
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(2)
    result = sock.connect_ex((host, port))
    sock.close()
    
    if result == 0:
        # Port is open - MariaDB is accessible
        # Try database connection if pymysql is available
        try:
            import pymysql
            password = "$db_root_password"
            try:
                if password:
                    conn = pymysql.connect(
                        host=host,
                        port=port,
                        user='root',
                        password=password,
                        connect_timeout=2
                    )
                else:
                    # Try without password (local MariaDB often has no root password)
                    conn = pymysql.connect(
                        host=host,
                        port=port,
                        user='root',
                        connect_timeout=2
                    )
                conn.close()
                sys.exit(0)  # Success - full connection works
            except Exception as e:
                # Port is open but DB connection failed - port check is enough for now
                # The actual connection will be tested when bench tries to connect
                sys.exit(0)  # Consider it ready if port is open
        except ImportError:
            # pymysql not available yet - just check port accessibility
            sys.exit(0)  # Port is open, that's enough
    else:
        sys.exit(1)  # Port not open
except Exception:
    sys.exit(1)  # Connection failed
PYEOF
            echo "✅ MariaDB is ready at $db_host:$db_port"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
        echo "   Attempt $attempt/$max_attempts: Waiting for MariaDB..."
        sleep 2
        fi
        attempt=$((attempt + 1))
    done
    
    echo "⚠️  Could not connect to MariaDB at $db_host:$db_port"
    echo "   This is OK if you're using local MariaDB - the connection will be tested later"
    echo "   Make sure MariaDB is running: brew services start mariadb"
    return 1
}

# Wait for database (non-blocking - will continue even if connection fails)
# This is especially important when connecting to local MariaDB from container
wait_for_mariadb || {
    echo "ℹ️  Continuing without MariaDB connection check..."
    echo "   The connection will be verified when the site is initialized"
}

# Verify bench structure exists
if [ ! -d "apps/frappe" ]; then
    echo "❌ Error: Frappe app not found! The source code may not have been copied correctly."
    exit 1
fi

echo "✅ Bench structure verified"

# Initialize git repositories for apps if they don't exist
# Bench expects apps to be git repositories, so we create them if missing
echo "🔧 Checking git repositories for apps..."
if command -v git >/dev/null 2>&1; then
    for app_dir in apps/*/; do
        if [ -d "$app_dir" ]; then
            app_name=$(basename "$app_dir")
            if [ ! -d "$app_dir/.git" ]; then
                echo "   Initializing git repository for $app_name..."
                cd "$app_dir" || continue
                if git init --quiet 2>/dev/null; then
                    git config user.email "frappe@localhost" 2>/dev/null || true
                    git config user.name "Frappe" 2>/dev/null || true
                    # Add all files and create initial commit
                    git add . >/dev/null 2>&1 || true
                    git commit -m "Initial commit" --allow-empty --quiet >/dev/null 2>&1 || true
                    echo "   ✅ Git repository initialized for $app_name"
                else
                    echo "   ⚠️  Failed to initialize git repository for $app_name"
                fi
                cd "$BENCH_DIR" || exit 1
            else
                echo "   ✅ $app_name already has a git repository"
            fi
        fi
    done
else
    echo "   ⚠️  Git not found, skipping git repository initialization"
    echo "   ⚠️  This may cause issues with bench setup requirements"
fi

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
        
        # Use environment variables or Docker defaults
        redis_cache = os.environ.get('REDIS_CACHE', 'redis://redis:6379')
        redis_queue = os.environ.get('REDIS_QUEUE', 'redis://redis:6379')
        redis_socketio = os.environ.get('REDIS_SOCKETIO', 'redis://redis:6379')
        
        config['redis_cache'] = redis_cache
        config['redis_queue'] = redis_queue
        config['redis_socketio'] = redis_socketio
        
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
    # Use database credentials from .env file (already loaded above)
    # FRAPPE_DB_HOST, FRAPPE_DB_PORT, etc. are already set from .env
    export FRAPPE_DB_SOCKET=""
    
    # Try to connect to database
    if bench --site "$SITE_NAME" list-apps >/dev/null 2>&1; then
        DB_CONNECTION_WORKS=true
        echo "✅ Database connection working"
    else
        echo "⚠️  Database connection failed, trying to update site config..."
        # Don't remove site, just try to update config
        SITE_EXISTS=true  # Keep existing site
    fi
fi

if [ "$SITE_EXISTS" = false ]; then
    echo "🌐 Creating site: $SITE_NAME"
    
    # Ensure environment variables are set for bench
    export PATH="$(pwd)/env/bin:$PATH"
    export VIRTUAL_ENV="$(pwd)/env"
    export FRAPPE_BENCH_ROOT="$(pwd)"
    
    # Database environment variables are already set from .env file
    # Ensure TCP connection (no socket)
    export FRAPPE_DB_SOCKET=""
    
    # Create site with database credentials from .env file
    bench new-site "$SITE_NAME" \
        --db-host "${FRAPPE_DB_HOST:-host.docker.internal}" \
        --db-port "${FRAPPE_DB_PORT:-${DB_PORT:-3306}}" \
        --db-name "${FRAPPE_DB_NAME}" \
        --db-user "${FRAPPE_DB_USER}" \
        --db-password "${FRAPPE_DB_PASSWORD}" \
        --mariadb-root-password "${MARIADB_ROOT_PASSWORD:-}" \
        --admin-password "${ADMIN_PASSWORD:-admin}" \
        --no-mariadb-socket || {
        echo "⚠️  Site creation had issues, but continuing..."
    }
fi

# Always ensure site configuration uses TCP connection to local MariaDB (fix existing sites too)
# This allows Docker to use the same database as local development
if [ -d "sites/$SITE_NAME" ] && [ -f "sites/$SITE_NAME/site_config.json" ]; then
    echo "🔧 Updating site database configuration to use database from .env file..."
    SITE_NAME_VALUE="$SITE_NAME" \
    FRAPPE_DB_HOST_VALUE="${FRAPPE_DB_HOST:-host.docker.internal}" \
    FRAPPE_DB_PORT_VALUE="${FRAPPE_DB_PORT:-${DB_PORT:-3306}}" \
    FRAPPE_DB_NAME_VALUE="${FRAPPE_DB_NAME}" \
    FRAPPE_DB_USER_VALUE="${FRAPPE_DB_USER}" \
    FRAPPE_DB_PASSWORD_VALUE="${FRAPPE_DB_PASSWORD}" \
    "$PYTHON_EXE" -c "
import json
import os

site_name = os.environ['SITE_NAME_VALUE']
db_host = os.environ.get('FRAPPE_DB_HOST_VALUE', 'host.docker.internal')
db_port = int(os.environ.get('FRAPPE_DB_PORT_VALUE', os.environ.get('DB_PORT', '3306')))
db_name = os.environ.get('FRAPPE_DB_NAME_VALUE', '')
db_user = os.environ.get('FRAPPE_DB_USER_VALUE', '')
db_password = os.environ.get('FRAPPE_DB_PASSWORD_VALUE', '')
config_file = f'sites/{site_name}/site_config.json'

try:
    if os.path.exists(config_file):
        with open(config_file, 'r') as f:
            config = json.load(f)
        
        old_host = config.get('db_host', 'localhost')
        old_port = config.get('db_port', int(os.environ.get('DB_PORT', '3306')))
        old_name = config.get('db_name', '')
        old_user = config.get('db_user', '')
        
        # Update database configuration from .env file
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
        
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=1)
        
        changes = []
        if old_host != db_host or old_port != db_port:
            changes.append(f'host:port from {old_host}:{old_port} to {db_host}:{db_port}')
        if db_name and old_name != db_name:
            changes.append(f'database from {old_name} to {db_name}')
        if db_user and old_user != db_user:
            changes.append(f'user from {old_user} to {db_user}')
        
        if changes:
            print(f'✅ Updated site database configuration: {\", \".join(changes)}')
        else:
            print(f'✅ Verified site database configuration uses: {db_host}:{db_port}/{db_name}')
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
    
    # Database environment variables are already set from .env file
    # Ensure TCP connection (no socket)
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

# Ensure asset symlinks exist before building
echo "🔗 Ensuring asset symlinks..."
export PATH="$(pwd)/env/bin:$PATH"
export VIRTUAL_ENV="$(pwd)/env"
export FRAPPE_BENCH_ROOT="$(pwd)"
# Create asset symlinks if they don't exist
if [ ! -L "sites/assets/frappe" ] && [ -d "apps/frappe/frappe/public" ]; then
    ln -sf "$(pwd)/apps/frappe/frappe/public" "sites/assets/frappe" 2>/dev/null || true
    echo "   ✅ Created frappe asset symlink"
fi
if [ ! -L "sites/assets/lms" ] && [ -d "apps/lms/lms/public" ]; then
    ln -sf "$(pwd)/apps/lms/lms/public" "sites/assets/lms" 2>/dev/null || true
    echo "   ✅ Created lms asset symlink"
fi

# Build assets (ensure CSS/JS bundles exist)
echo "🎨 Building assets..."

# Check if assets need to be built
ASSETS_NEED_BUILD=false
ASSETS_JSON="sites/assets/assets.json"

if [ ! -f "$ASSETS_JSON" ] || [ ! -s "$ASSETS_JSON" ]; then
    ASSETS_NEED_BUILD=true
    echo "   assets.json missing or empty, assets need to be built"
else
    # Check if CSS bundle directories exist
    if [ ! -d "sites/assets/frappe/dist/css" ] || [ -z "$(ls -A sites/assets/frappe/dist/css 2>/dev/null)" ]; then
        ASSETS_NEED_BUILD=true
        echo "   Frappe CSS bundles missing, assets need to be built"
    elif [ ! -d "sites/assets/lms/dist/css" ] || [ -z "$(ls -A sites/assets/lms/dist/css 2>/dev/null)" ]; then
        ASSETS_NEED_BUILD=true
        echo "   LMS CSS bundles missing, assets need to be built"
    fi
fi

if [ "$ASSETS_NEED_BUILD" = true ]; then
    echo "   Building all assets (this may take a few minutes)..."
    # Build assets for all apps (frappe and lms)
    # Use --force to ensure fresh build
    if bench build --force 2>&1; then
        echo "✅ Assets built successfully"
        # Update assets.json to ensure it's in sync
        bench build --using-cached > /dev/null 2>&1 || true
        # Clear cache after building
        bench --site "$SITE_NAME" clear-cache 2>/dev/null || true
    else
        echo "⚠️  Asset build with --force had issues, trying without --force..."
        # Try without --force as fallback
        if bench build 2>&1; then
            echo "✅ Assets built successfully (without --force)"
            # Update assets.json to ensure it's in sync
            bench build --using-cached > /dev/null 2>&1 || true
            bench --site "$SITE_NAME" clear-cache 2>/dev/null || true
        else
            echo "⚠️  Asset build failed, but continuing..."
            echo "   You can manually build assets later with: bench build"
        fi
    fi
else
    echo "✅ Assets are up to date"
fi

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

# Use Docker-specific Procfile (without Redis processes - using external Redis container)
echo "🔧 Configuring Procfile for Docker..."
if [ -f "Procfile.docker" ]; then
    # Backup original Procfile if it exists and isn't already the Docker version
    if [ -f "Procfile" ] && ! grep -q "# Docker-specific Procfile" Procfile 2>/dev/null; then
        cp Procfile Procfile.local 2>/dev/null || true
    fi
    # Use Docker-specific Procfile
    cp Procfile.docker Procfile
    echo "✅ Using Procfile.docker (Redis processes disabled - using external Redis container)"
elif [ -f "Procfile" ]; then
    echo "⚠️  Procfile.docker not found, using default Procfile"
    echo "   Note: Redis processes may fail if redis-server is not installed"
fi

# Start bench (using Docker-specific Procfile without local Redis)
# Use exec to replace shell process
exec bench start

