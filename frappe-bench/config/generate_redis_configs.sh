#!/bin/bash
# Generate Redis config files with dynamic paths
# This script should be run from the bench directory

BENCH_DIR="${FRAPPE_BENCH_ROOT:-$(pwd)}"

# Generate redis_cache.conf with absolute paths
cat > "${BENCH_DIR}/config/redis_cache.conf" << EOF
dbfilename redis_cache.rdb
dir ${BENCH_DIR}/config/pids
pidfile ${BENCH_DIR}/config/pids/redis_cache.pid
bind 127.0.0.1
port 13000
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
port 11000
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

