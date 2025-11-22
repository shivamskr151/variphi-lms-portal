#!/bin/bash
# Comprehensive Docker management script for LMS
# Handles setup checks, Docker Desktop startup, and all docker-compose operations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Docker is running
check_docker() {
    if docker info > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to start Docker Desktop on macOS
start_docker_desktop() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [ -d "/Applications/Docker.app" ]; then
            echo "🐳 Starting Docker Desktop..."
            open -a Docker
            echo "⏳ Waiting for Docker Desktop to start (this may take 30-60 seconds)..."
            
            # Wait up to 60 seconds for Docker to start
            local max_attempts=60
            local attempt=0
            while [ $attempt -lt $max_attempts ]; do
                if check_docker; then
                    echo "✅ Docker Desktop is now running!"
                    return 0
                fi
                sleep 1
                attempt=$((attempt + 1))
                if [ $((attempt % 10)) -eq 0 ]; then
                    echo "   Still waiting... (${attempt}s)"
                fi
            done
            
            echo "⚠️  Docker Desktop is taking longer than expected to start."
            echo "   Please wait a bit more and try again, or start Docker Desktop manually."
            return 1
        else
            echo "❌ Docker Desktop not found in /Applications/Docker.app"
            echo "   Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
            return 1
        fi
    else
        echo "❌ Docker daemon is not running."
        echo "   Please start Docker manually for your system."
        return 1
    fi
}

# Pull Docker images with retry logic
pull_images_with_retry() {
    local max_retries=3
    local retry_delay=5
    local images=("mariadb:10.8" "redis:alpine")
    
    echo "📥 Checking and pulling required Docker images..."
    echo ""
    
    for image in "${images[@]}"; do
        # Check if image already exists locally
        if docker image inspect "$image" >/dev/null 2>&1; then
            echo "✅ $image already exists locally, skipping pull"
            echo ""
            continue
        fi
        
        local attempt=1
        local success=false
        local current_delay=$retry_delay
        
        while [ $attempt -le $max_retries ]; do
            echo "🔄 Pulling $image (attempt $attempt/$max_retries)..."
            
            # Use a temporary file for output
            local temp_log=$(mktemp)
            if docker pull "$image" > "$temp_log" 2>&1; then
                echo "✅ Successfully pulled $image"
                rm -f "$temp_log"
                success=true
                break
            else
                local error=$(tail -5 "$temp_log" 2>/dev/null | grep -i "timeout\|connection\|network\|handshake" || tail -1 "$temp_log" 2>/dev/null)
                rm -f "$temp_log"
                
                if echo "$error" | grep -qi "TLS handshake timeout\|timeout\|connection\|network"; then
                    if [ $attempt -lt $max_retries ]; then
                        echo "⚠️  Network timeout detected. Retrying in ${current_delay} seconds..."
                        sleep $current_delay
                        current_delay=$((current_delay * 2))  # Exponential backoff
                    else
                        echo "❌ Failed to pull $image after $max_retries attempts"
                        echo "   Last error: $error"
                        echo ""
                        echo "💡 Troubleshooting tips:"
                        echo "   1. Check your internet connection"
                        echo "   2. Try again later (network issues may be temporary)"
                        echo "   3. Check Docker Desktop network settings"
                        echo "   4. Try manually: docker pull $image"
                        echo "   5. Check if you're behind a proxy/firewall"
                        return 1
                    fi
                else
                    echo "❌ Failed to pull $image"
                    echo "   Error: $error"
                    return 1
                fi
            fi
            
            attempt=$((attempt + 1))
        done
        
        if [ "$success" = false ]; then
            return 1
        fi
        
        echo ""
    done
    
    echo "✅ All images are ready!"
    echo ""
    return 0
}

# Comprehensive setup check
check_setup() {
    echo "🔍 Checking Docker Setup Compatibility..."
    echo ""

    # Check OS
    echo "📱 Operating System:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   ✅ macOS detected"
        OS="macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "   ✅ Linux detected"
        OS="Linux"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "   ✅ Windows (WSL/Cygwin) detected"
        OS="Windows"
    else
        echo "   ⚠️  Unknown OS: $OSTYPE"
        OS="Unknown"
    fi
    echo ""

    # Check Docker
    echo "🐳 Docker:"
    DOCKER_RUNNING=true
    if command -v docker >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version 2>&1)
        echo "   ✅ Docker installed: $DOCKER_VERSION"
        
        if docker info >/dev/null 2>&1; then
            echo "   ✅ Docker daemon is running"
        else
            echo "   ❌ Docker daemon is not running"
            echo "      Please start Docker Desktop or Docker daemon"
            DOCKER_RUNNING=false
        fi
    else
        echo "   ❌ Docker not installed"
        echo "      Please install Docker from https://www.docker.com/products/docker-desktop"
        return 1
    fi
    echo ""

    # Check Docker Compose
    echo "🐙 Docker Compose:"
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker-compose --version 2>&1)
        echo "   ✅ Docker Compose installed: $COMPOSE_VERSION"
    elif docker compose version >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version 2>&1)
        echo "   ✅ Docker Compose (plugin) installed: $COMPOSE_VERSION"
    else
        echo "   ❌ Docker Compose not found"
        echo "      Please install Docker Compose"
        return 1
    fi
    echo ""

    # Check ports
    echo "🔌 Port Availability:"
    check_port() {
        local port=$1
        if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                echo "   ⚠️  Port $port is already in use"
                return 1
            else
                echo "   ✅ Port $port is available"
                return 0
            fi
        elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
            if netstat -ano | grep -q ":$port.*LISTENING"; then
                echo "   ⚠️  Port $port is already in use"
                return 1
            else
                echo "   ✅ Port $port is available"
                return 0
            fi
        else
            echo "   ⚠️  Cannot check port $port (unknown OS)"
            return 0
        fi
    }

    check_port 8000
    check_port 9000
    echo ""

    # Check disk space
    echo "💾 Disk Space:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        AVAILABLE=$(df -h . | tail -1 | awk '{print $4}')
        echo "   Available: $AVAILABLE"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        AVAILABLE=$(df -h . | tail -1 | awk '{print $4}')
        echo "   Available: $AVAILABLE"
    else
        echo "   ⚠️  Cannot check disk space on this OS"
    fi
    echo ""

    # Check memory (if possible)
    echo "🧠 System Resources:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        TOTAL_MEM=$(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024}')
        echo "   Total RAM: ${TOTAL_MEM}GB"
        echo "   ⚠️  Ensure Docker Desktop has at least 4GB allocated"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
        echo "   Total RAM: ${TOTAL_MEM}GB"
        if [ "$TOTAL_MEM" -lt 4 ]; then
            echo "   ⚠️  Warning: Less than 4GB RAM may cause issues"
        fi
    fi
    echo ""

    # Check if in correct directory
    echo "📁 Directory Check:"
    if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        echo "   ✅ In correct directory: $SCRIPT_DIR"
    else
        echo "   ❌ docker-compose.yml not found"
        echo "      Please run this script from apps/lms/docker directory"
        return 1
    fi
    echo ""

    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Summary:"
    echo ""

    if [ "$DOCKER_RUNNING" = false ]; then
        echo "❌ Docker daemon is not running"
        echo "   Please start Docker and try again"
        return 1
    fi

    echo "✅ All checks passed!"
    echo ""
    echo "🚀 You can now run:"
    echo "   ./docker-run.sh up"
    echo "   or"
    echo "   docker-compose up"
    echo ""
}

# Main script logic
main() {
    case "${1:-up}" in
        check)
            check_setup
            ;;
        build)
            if ! check_docker; then
                echo "❌ Docker daemon is not running."
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    echo ""
                    read -p "Would you like to start Docker Desktop now? (y/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        if ! start_docker_desktop; then
                            exit 1
                        fi
                    else
                        exit 1
                    fi
                else
                    echo "Please start Docker Desktop or Docker daemon and try again."
                    exit 1
                fi
            fi
            set -e
            echo "Building Docker image..."
            docker-compose build
            ;;
        up)
            if ! check_docker; then
                echo "❌ Docker daemon is not running."
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    echo ""
                    read -p "Would you like to start Docker Desktop now? (y/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        if ! start_docker_desktop; then
                            exit 1
                        fi
                    else
                        exit 1
                    fi
                else
                    echo "Please start Docker Desktop or Docker daemon and try again."
                    exit 1
                fi
            fi
            
            # Pull images with retry logic first
            if ! pull_images_with_retry; then
                echo ""
                echo "❌ Failed to pull required Docker images."
                echo "   Please check your network connection and try again."
                exit 1
            fi
            
            set -e
            echo "Starting Docker services..."
            docker-compose up
            ;;
        down)
            if ! check_docker; then
                echo "⚠️  Docker daemon is not running. Nothing to stop."
                exit 0
            fi
            set -e
            echo "Stopping Docker services..."
            docker-compose down
            ;;
        restart)
            if ! check_docker; then
                echo "❌ Docker daemon is not running."
                exit 1
            fi
            set -e
            echo "Restarting Docker services..."
            docker-compose restart
            ;;
        logs)
            if ! check_docker; then
                echo "❌ Docker daemon is not running."
                exit 1
            fi
            set -e
            echo "Showing logs..."
            docker-compose logs -f "${2:-frappe}"
            ;;
        shell)
            if ! check_docker; then
                echo "❌ Docker daemon is not running."
                exit 1
            fi
            set -e
            echo "Opening shell in frappe container..."
            docker-compose exec frappe bash
            ;;
        pull)
            if ! check_docker; then
                echo "❌ Docker daemon is not running."
                exit 1
            fi
            pull_images_with_retry
            ;;
        rebuild)
            if ! check_docker; then
                echo "❌ Docker daemon is not running."
                exit 1
            fi
            set -e
            echo "Rebuilding Docker image (no cache)..."
            docker-compose build --no-cache
            ;;
        reset)
            if ! check_docker; then
                echo "⚠️  Docker daemon is not running. Nothing to reset."
                exit 0
            fi
            set -e
            echo "⚠️  WARNING: This will delete all data including database and bench setup!"
            read -p "Are you sure? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                docker-compose down --volumes
                echo "Volumes removed. Run './docker-run.sh build' and './docker-run.sh up' to start fresh."
            else
                echo "Cancelled."
            fi
            ;;
        *)
            echo "Usage: $0 {check|build|pull|up|down|restart|logs|shell|rebuild|reset}"
            echo ""
            echo "Commands:"
            echo "  check    - Check Docker setup and system requirements"
            echo "  build    - Build the Docker image (first time or after Dockerfile changes)"
            echo "  pull     - Pull required Docker images with retry logic"
            echo "  up       - Start all services (default, automatically pulls images)"
            echo "  down     - Stop all services"
            echo "  restart  - Restart all services"
            echo "  logs     - Show logs (optionally specify service: frappe, mariadb, redis)"
            echo "  shell    - Open bash shell in frappe container"
            echo "  rebuild  - Rebuild image without cache"
            echo "  reset    - Stop services and remove all volumes (complete reset)"
            exit 1
            ;;
    esac
}

main "$@"
