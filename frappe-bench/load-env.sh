#!/bin/bash
# Helper script to load .env file consistently across all scripts
# Usage: source load-env.sh
# Or: . load-env.sh

# Get the directory where this script is located
if [ -n "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Fallback for sh
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Load .env file if it exists
ENV_FILE="$SCRIPT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    # Export all variables from .env
    set -a
    source "$ENV_FILE"
    set +a
    return 0 2>/dev/null || exit 0
else
    # .env file doesn't exist, but that's okay - scripts can use defaults
    return 0 2>/dev/null || exit 0
fi

