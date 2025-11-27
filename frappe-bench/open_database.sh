#!/bin/bash
# Script to help open database in GUI tools
# Usage: ./open_database.sh [tool]

# Auto-detect bench directory
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BENCH_DIR"

# Load environment variables from .env
if [ -f "$BENCH_DIR/.env" ]; then
    set -a
    source "$BENCH_DIR/.env"
    set +a
fi

# Get site name
SITE_NAME="${SITE_NAME:-vgi.local}"

# Load database credentials from site_config.json if available (preferred source)
SITE_CONFIG="$BENCH_DIR/sites/$SITE_NAME/site_config.json"
if [ -f "$SITE_CONFIG" ]; then
    SITE_DB_NAME=$(python3 -c "import json; f=open('$SITE_CONFIG'); c=json.load(f); print(c.get('db_name', '')); f.close()" 2>/dev/null || echo "")
    SITE_DB_USER=$(python3 -c "import json; f=open('$SITE_CONFIG'); c=json.load(f); print(c.get('db_user', '')); f.close()" 2>/dev/null || echo "")
    SITE_DB_PASS=$(python3 -c "import json; f=open('$SITE_CONFIG'); c=json.load(f); print(c.get('db_password', '')); f.close()" 2>/dev/null || echo "")
    SITE_DB_HOST=$(python3 -c "import json; f=open('$SITE_CONFIG'); c=json.load(f); print(c.get('db_host', '127.0.0.1')); f.close()" 2>/dev/null || echo "127.0.0.1")
    SITE_DB_PORT=$(python3 -c "import json; f=open('$SITE_CONFIG'); c=json.load(f); print(c.get('db_port', '3306')); f.close()" 2>/dev/null || echo "3306")
fi

# Use site_config.json values if available, otherwise fall back to .env variables
DB_NAME="${SITE_DB_NAME:-${DB_NAME}}"
DB_USER="${SITE_DB_USER:-${DB_USER}}"
DB_PASS="${SITE_DB_PASS:-${DB_PASSWORD}}"
DB_HOST="${SITE_DB_HOST:-${DB_HOST:-127.0.0.1}}"
DB_PORT="${SITE_DB_PORT:-${DB_PORT:-3306}}"

# Validate credentials
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "Error: Database credentials not found."
    echo "Please run: ./setup-env.sh"
    echo "Or ensure .env file exists with DB_NAME, DB_USER, and DB_PASSWORD set"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Database Connection Information ===${NC}"
echo ""
echo -e "Host: ${GREEN}$DB_HOST${NC}"
echo -e "Port: ${GREEN}$DB_PORT${NC}"
echo -e "Database: ${GREEN}$DB_NAME${NC}"
echo -e "Username: ${GREEN}$DB_USER${NC}"
echo -e "Password: ${GREEN}$DB_PASS${NC}"
echo ""
echo -e "${BLUE}Connection String:${NC}"
echo "mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# Try to open with available tools
case "$1" in
    workbench)
        if command -v mysql-workbench &> /dev/null; then
            echo -e "${BLUE}Opening MySQL Workbench...${NC}"
            mysql-workbench "mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME" &
        else
            echo -e "${YELLOW}MySQL Workbench not found.${NC}"
            echo "Install with: brew install --cask mysql-workbench"
        fi
        ;;
    tableplus)
        if command -v tableplus &> /dev/null; then
            echo -e "${BLUE}Opening TablePlus...${NC}"
            open "mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME"
        else
            echo -e "${YELLOW}TablePlus not found.${NC}"
            echo "Install with: brew install --cask tableplus"
        fi
        ;;
    dbeaver)
        if command -v dbeaver &> /dev/null; then
            echo -e "${BLUE}DBeaver connection command:${NC}"
            echo "dbeaver -con 'name=Frappe|driver=mysql|host=$DB_HOST|port=$DB_PORT|database=$DB_NAME|user=$DB_USER|password=$DB_PASS'"
        else
            echo -e "${YELLOW}DBeaver not found.${NC}"
            echo "Install with: brew install --cask dbeaver-community"
        fi
        ;;
    *)
        echo -e "${BLUE}Available GUI Tools:${NC}"
        echo ""
        echo "1. ${GREEN}MySQL Workbench${NC} (brew install --cask mysql-workbench)"
        echo "2. ${GREEN}TablePlus${NC} (brew install --cask tableplus)"
        echo "3. ${GREEN}DBeaver${NC} (brew install --cask dbeaver-community)"
        echo "4. ${GREEN}Sequel Pro${NC} (brew install --cask sequel-pro)"
        echo ""
        echo -e "${YELLOW}Note:${NC} This is a MariaDB/MySQL database, not SQLite."
        echo "DB Browser for SQLite won't work with this database."
        echo ""
        echo "Use this script to open specific tools:"
        echo "  ./open_database.sh workbench  # Open MySQL Workbench"
        echo "  ./open_database.sh tableplus  # Open TablePlus"
        echo "  ./open_database.sh dbeaver    # Show DBeaver connection info"
        echo ""
        echo "Or manually connect using the credentials above."
        ;;
esac

