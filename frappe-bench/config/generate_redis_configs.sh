#!/bin/bash
# Generate Redis config files with dynamic paths
# This script should be run from the bench directory

BENCH_DIR="${FRAPPE_BENCH_ROOT:-$(pwd)}"

# Load environment variables from .env if it exists
if [ -f "$BENCH_DIR/.env" ]; then
    set -a
    source "$BENCH_DIR/.env"
    set +a
fi

# Use environment variables with defaults
REDIS_CACHE_PORT="${REDIS_CACHE_PORT:-13000}"
REDIS_QUEUE_PORT="${REDIS_QUEUE_PORT:-11000}"

# Generate redis_cache.conf with absolute paths
cat > "${BENCH_DIR}/config/redis_cache.conf" << EOF
dbfilename redis_cache.rdb
dir ${BENCH_DIR}/config/pids
pidfile ${BENCH_DIR}/config/pids/redis_cache.pid
bind 127.0.0.1
port ${REDIS_CACHE_PORT}
maxmemory 291mb
maxmemory-policy allkeys-lru
appendonly no

save ""

aclfile ${BENCH_DIR}/config/redis_cache.acl
EOF

# Generate redis_queue.conf with absolute paths
cat > "${BENCH_DIR}/config/redis_queue.conf" << EOF
# Redis Queue Configuration
# Auto-generated - do not edit manually

dbfilename redis_queue.rdb
dir ${BENCH_DIR}/config/pids
pidfile ${BENCH_DIR}/config/pids/redis_queue.pid
bind 127.0.0.1
port ${REDIS_QUEUE_PORT}
protected-mode yes
tcp-backlog 511
timeout 0
tcp-keepalive 300

# Disable persistence for queue (not needed)
save ""
appendonly no

aclfile ${BENCH_DIR}/config/redis_queue.acl
EOF

echo "Redis config files generated with dynamic paths"
echo "Bench directory: ${BENCH_DIR}"

