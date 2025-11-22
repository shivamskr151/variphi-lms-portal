#!/bin/bash
set -e

# Fix permissions on bench directory if it's owned by root
BENCH_DIR="/home/frappe/frappe-bench"

if [ -d "$BENCH_DIR" ]; then
    # Check if directory is writable by frappe user
    if [ ! -w "$BENCH_DIR" ]; then
        echo "Fixing permissions on bench directory..."
        # If we're running as root (during initial setup), fix permissions
        if [ "$(id -u)" = "0" ]; then
            chown -R frappe:frappe "$BENCH_DIR" || true
        fi
    fi
fi

# If running as root, switch to frappe user and run init script
if [ "$(id -u)" = "0" ]; then
    # Try gosu first (installed in Dockerfile), fallback to su
    if command -v gosu >/dev/null 2>&1; then
        exec gosu frappe "$@"
    elif command -v su-exec >/dev/null 2>&1; then
        exec su-exec frappe "$@"
    else
        # Fallback to su
        exec su - frappe -c "cd /home/frappe && exec $*"
    fi
else
    exec "$@"
fi

