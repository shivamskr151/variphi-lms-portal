#!/bin/bash
# Quick database access script for Frappe Bench
#
# USAGE GUIDE:
# ------------
# 1. Interactive MySQL Shell:
#    ./access_database.sh                    # Opens MySQL shell, type SQL commands, use 'exit;' or Ctrl+D to quit
#
# 2. Quick Commands (no interactive shell):
#    ./access_database.sh info               # Show database info, tables, and size
#    ./access_database.sh tables             # List all tables
#    ./access_database.sh status             # Check database connection status
#    ./access_database.sh backup             # Create a database backup
#    ./access_database.sh help               # Show this help message
#
# 3. Run SQL Commands:
#    ./access_database.sh "SHOW TABLES;"                    # List tables
#    ./access_database.sh "SELECT COUNT(*) FROM tabUser;"   # Count users
#    ./access_database.sh "DESCRIBE tabUser;"               # Show table structure
#
# EXAMPLES:
# ---------
#   ./access_database.sh                    # Open interactive MySQL shell
#   ./access_database.sh "SHOW TABLES;"     # Run a single SQL command
#   ./access_database.sh info               # Show database information

# Database credentials from site_config.json (vgi.local)
# Auto-detected from sites/vgi.local/site_config.json
DB_USER="_517a1fbab7ba0c04"
DB_PASS="yIawHBFVcaiAKaJw"
DB_NAME="_517a1fbab7ba0c04"
DB_HOST="127.0.0.1"
DB_PORT="3306"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Change to bench directory
cd "$(dirname "${BASH_SOURCE[0]}")"

show_info() {
    echo -e "${BLUE}=== Database Information ===${NC}"
    echo -e "Database: ${GREEN}$DB_NAME${NC}"
    echo -e "User: ${GREEN}$DB_USER${NC}"
    echo -e "Host: ${GREEN}$DB_HOST${NC}"
    echo ""
    
    echo -e "${BLUE}Database Tables:${NC}"
    mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME" -e "SHOW TABLES;" 2>/dev/null | head -30
    
    echo ""
    echo -e "${BLUE}Database Size:${NC}"
    mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME" -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES WHERE table_schema = '$DB_NAME' GROUP BY table_schema;" 2>/dev/null
}

# If no arguments, open interactive shell
if [ $# -eq 0 ]; then
    echo -e "${BLUE}Connecting to database: ${GREEN}$DB_NAME${NC}"
    echo -e "${YELLOW}Type 'exit' or press Ctrl+D to quit${NC}"
    echo ""
    mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME"
    exit 0
fi

# Handle special commands
case "$1" in
    info)
        show_info
        ;;
    tables)
        echo -e "${BLUE}Listing all tables:${NC}"
        mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME" -e "SHOW TABLES;"
        ;;
    status)
        echo -e "${BLUE}Database Status:${NC}"
        mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME" -e "SELECT 'Connection Status' AS Status, 'OK' AS Result; SELECT COUNT(*) AS 'Total Tables' FROM information_schema.tables WHERE table_schema = '$DB_NAME';"
        ;;
    backup)
        BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
        echo -e "${BLUE}Creating backup: ${GREEN}$BACKUP_FILE${NC}"
        mysqldump -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME" > "$BACKUP_FILE"
        echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"
        ;;
    help)
        echo "Database Access Script"
        echo ""
        echo "Usage:"
        echo "  ./access_database.sh                    # Open MySQL interactive shell"
        echo "  ./access_database.sh \"SQL_COMMAND\"     # Run a single SQL command"
        echo "  ./access_database.sh info               # Show database information"
        echo "  ./access_database.sh tables             # List all tables"
        echo "  ./access_database.sh status             # Check database status"
        echo "  ./access_database.sh backup             # Create a database backup"
        echo ""
        echo "Examples:"
        echo "  ./access_database.sh \"SHOW TABLES;\""
        echo "  ./access_database.sh \"SELECT COUNT(*) FROM tabUser;\""
        echo "  ./access_database.sh \"DESCRIBE tabUser;\""
        ;;
    *)
        # Run the SQL command provided
        echo -e "${BLUE}Executing SQL command...${NC}"
        mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME" -e "$1"
        ;;
esac

