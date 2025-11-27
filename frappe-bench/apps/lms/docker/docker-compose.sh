#!/bin/bash
# Docker Compose Wrapper Script
# Loads .env file and ensures Docker is running before executing docker-compose commands

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Load .env file if it exists
if [ -f "$BENCH_DIR/.env" ]; then
    set -a
    source "$BENCH_DIR/.env"
    set +a
fi

# Check Docker is running
source "$SCRIPT_DIR/docker-check.sh"

# Change to docker directory
cd "$SCRIPT_DIR"

# Execute docker-compose with all arguments
exec docker-compose "$@"

