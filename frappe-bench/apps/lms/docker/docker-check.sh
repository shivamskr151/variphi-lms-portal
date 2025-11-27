#!/bin/bash
# Docker Health Check Script
# Ensures Docker is running before executing docker-compose commands

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    echo "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    log_warning "Docker daemon is not running"
    echo ""
    log_info "Attempting to start Docker Desktop..."
    
    # Try to open Docker Desktop (macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if open -a Docker &> /dev/null; then
            log_info "Docker Desktop is starting..."
            log_info "Please wait for Docker Desktop to fully start (this may take 30-60 seconds)"
            echo ""
            
            # Wait for Docker to be ready (max 60 seconds)
            MAX_WAIT=60
            ELAPSED=0
            while [ $ELAPSED -lt $MAX_WAIT ]; do
                if docker info &> /dev/null; then
                    log_success "Docker is now running!"
                    break
                fi
                sleep 2
                ELAPSED=$((ELAPSED + 2))
                echo -n "."
            done
            echo ""
            
            if ! docker info &> /dev/null; then
                log_error "Docker did not start within $MAX_WAIT seconds"
                log_info "Please start Docker Desktop manually and try again"
                exit 1
            fi
        else
            log_error "Could not start Docker Desktop automatically"
            log_info "Please start Docker Desktop manually:"
            echo "  1. Open Applications folder"
            echo "  2. Double-click Docker.app"
            echo "  3. Wait for Docker to start (whale icon in menu bar)"
            echo "  4. Run this command again"
            exit 1
        fi
    else
        log_error "Please start Docker manually"
        log_info "On Linux, try: sudo systemctl start docker"
        exit 1
    fi
fi

# Verify Docker is working
if docker ps &> /dev/null; then
    log_success "Docker is running and ready"
    return 0 2>/dev/null || exit 0
else
    log_error "Docker is installed but not responding"
    exit 1
fi

