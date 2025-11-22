#!/bin/bash
# Script to help open database in GUI tools
# Usage: ./open_database.sh [tool]

# Database credentials
DB_USER="_2ca05118bd4124f3"
DB_PASS="vAhQPAHJpRcIsQmi"
DB_NAME="_2ca05118bd4124f3"
DB_HOST="localhost"
DB_PORT="3306"

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

