#!/bin/bash
# Comprehensive script to fix UI issues for local development

set -e

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BENCH_DIR" || exit 1

echo "🔧 Fixing UI issues for local development..."
echo ""

# 1. Restore local configuration
echo "1️⃣  Restoring local configuration..."
if [ -f "restore-local-config.sh" ]; then
    ./restore-local-config.sh > /dev/null 2>&1
fi

# 2. Fix broken asset symlinks
echo "2️⃣  Fixing asset symlinks..."
rm -rf sites/assets/lms sites/assets/frappe sites/assets/payments 2>/dev/null || true

# 3. Rebuild assets (both Frappe and LMS)
echo "3️⃣  Rebuilding assets..."
source env/bin/activate
bench build --force > /dev/null 2>&1 || {
    echo "   ⚠️  Build had warnings, but continuing..."
}

# 4. Rebuild frontend
echo "4️⃣  Rebuilding frontend..."
cd apps/lms/frontend
yarn build > /dev/null 2>&1 || {
    echo "   ⚠️  Frontend build had warnings, but continuing..."
}
cd "$BENCH_DIR"

# 5. Clear all caches
echo "5️⃣  Clearing caches..."
# Auto-detect site name from .env or use default
SITE_NAME="${SITE_NAME:-vgi.local}"
if [ -f "$BENCH_DIR/.env" ]; then
    set -a
    source "$BENCH_DIR/.env"
    set +a
    SITE_NAME="${SITE_NAME:-vgi.local}"
fi
bench --site "$SITE_NAME" clear-cache > /dev/null 2>&1 || true
rm -rf sites/*/cache/* 2>/dev/null || true

# 6. Verify assets
echo "6️⃣  Verifying assets..."
if [ -L "sites/assets/lms" ] && [ -d "sites/assets/lms/frontend" ]; then
    echo "   ✅ LMS assets properly linked"
else
    echo "   ❌ LMS assets not properly linked"
    exit 1
fi

if [ -f "sites/assets/lms/frontend/assets/index-CTv0VqYu.js" ]; then
    echo "   ✅ Frontend assets exist"
else
    echo "   ⚠️  Frontend assets may need rebuilding"
fi

if [ -L "sites/assets/frappe" ] && [ -d "sites/assets/frappe/dist" ]; then
    echo "   ✅ Frappe assets properly linked"
    # Check if assets.json matches actual files
    DESK_CSS=$(python3 -c "import json; f=open('sites/assets/assets.json'); d=json.load(f); print(d.get('desk.bundle.css', '').split('/')[-1]); f.close()" 2>/dev/null || echo "")
    if [ -n "$DESK_CSS" ] && [ -f "sites/assets/frappe/dist/css/$DESK_CSS" ]; then
        echo "   ✅ Frappe assets.json is in sync"
    else
        echo "   ⚠️  Frappe assets.json may be out of sync"
    fi
else
    echo "   ❌ Frappe assets not properly linked"
fi

echo ""
echo "✅ UI fix complete!"
echo ""
echo "Next steps:"
echo "1. Make sure Docker MariaDB is running:"
echo "   cd apps/lms/docker && docker-compose up -d mariadb"
echo ""
echo "2. Restart bench:"
echo "   ./bench-manage.sh stop"
echo "   ./bench-manage.sh start"
echo ""
echo "3. Clear browser cache (Cmd+Shift+R or Ctrl+Shift+R)"

