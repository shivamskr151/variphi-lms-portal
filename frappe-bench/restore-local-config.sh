#!/bin/bash
# Script to restore local development configuration
# Run this after using Docker to restore local settings (Redis and Database)

set -e

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BENCH_DIR" || exit 1

echo "🔧 Restoring local configuration..."

# Use Python to update both Redis and Database configs
python3 << 'PYTHON_SCRIPT'
import json
import os
import glob

# Update common_site_config.json (Redis)
config_file = "sites/common_site_config.json"
if os.path.exists(config_file):
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
        
        # Update to local Redis ports
        config['redis_cache'] = 'redis://127.0.0.1:13000'
        config['redis_queue'] = 'redis://127.0.0.1:11000'
        config['redis_socketio'] = 'redis://127.0.0.1:11000'
        
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=1)
        print("✅ Restored local Redis configuration")
        print("   redis_cache: redis://127.0.0.1:13000")
        print("   redis_queue: redis://127.0.0.1:11000")
        print("   redis_socketio: redis://127.0.0.1:11000")
    except Exception as e:
        print(f"⚠️  Could not update Redis config: {e}")

# Update all site_config.json files (Database)
# Connect to Docker MariaDB on localhost:3307
site_configs = glob.glob("sites/*/site_config.json")
for site_config in site_configs:
    try:
        with open(site_config, 'r') as f:
            config = json.load(f)
        
        # Update database host to use local MariaDB (auto-detect port)
        if config.get('db_host') == 'mariadb':
            config['db_host'] = '127.0.0.1'
            # Auto-detect port: check which port MariaDB is running on
            import socket
            db_port = 3306  # default
            for port in [3306, 3307]:
                try:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(1)
                    result = sock.connect_ex(('127.0.0.1', port))
                    sock.close()
                    if result == 0:
                        db_port = port
                        break
                except:
                    pass
            config['db_port'] = db_port
            with open(site_config, 'w') as f:
                json.dump(config, f, indent=1)
            site_name = os.path.basename(os.path.dirname(site_config))
            print(f"✅ Updated {site_name} database config: 127.0.0.1:{db_port}")
    except Exception as e:
        print(f"⚠️  Could not update {site_config}: {e}")

PYTHON_SCRIPT

echo ""
echo "✅ Local configuration restored!"
echo "   - Redis: Using local instances (ports 11000, 13000)"
echo "   - Database: Using local MariaDB (port auto-detected)"
echo ""
echo "   Make sure MariaDB is running locally, then run: ./bench-manage.sh start"

