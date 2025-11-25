#!/bin/bash
set -e

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

BENCH_DIR="/home/frappe/frappe-bench"
WORKSPACE_DIR="/workspace"

# Change to home directory first
cd /home/frappe || exit

# Check if bench already exists and is valid
# A valid bench must have: apps/frappe directory, Procfile, AND env directory
BENCH_VALID=false
if [ -d "$BENCH_DIR/apps/frappe" ] && [ -f "$BENCH_DIR/Procfile" ] && [ -d "$BENCH_DIR/env" ]; then
    echo "✓ Bench directory exists, verifying it's valid..."
    cd "$BENCH_DIR" || exit
    
    # Try to run a bench command to verify it's valid
    # This is the real test - if bench doesn't recognize the directory, it's invalid
    set +e
    BENCH_VERSION_OUTPUT=$(bench --version 2>&1)
    BENCH_VERSION_EXIT=$?
    set -e
    
    if [ $BENCH_VERSION_EXIT -eq 0 ]; then
        # Also test a bench command that requires being in a bench directory
        set +e
        BENCH_TEST=$(bench list-apps 2>&1)
        BENCH_TEST_EXIT=$?
        set -e
        
        if [ $BENCH_TEST_EXIT -eq 0 ]; then
            BENCH_VALID=true
            echo "✓ Bench is valid, reusing existing setup..."
            
            # Ensure Redis and MariaDB settings are correct
            bench set-mariadb-host mariadb || true
            bench set-redis-cache-host redis://redis:6379 || true
            bench set-redis-queue-host redis://redis:6379 || true
            bench set-redis-socketio-host redis://redis:6379 || true
            
            # Check if payments app is installed (required for Payment Gateways)
            if [ ! -d "./apps/payments" ]; then
                echo "⚠️  Payments app not found, installing it..."
                if [ -d "$WORKSPACE_DIR/apps/payments" ] && [ -f "$WORKSPACE_DIR/apps/payments/pyproject.toml" ]; then
                    bench get-app payments "$WORKSPACE_DIR/apps/payments" || {
                        echo "Copying Payments app from workspace..."
                        cp -r "$WORKSPACE_DIR/apps/payments" ./apps/
                    }
                else
                    bench get-app payments || true
                fi
            fi
            
            # Check if site exists
            if [ -d "$BENCH_DIR/sites/lms.localhost" ]; then
                echo "✓ Site lms.localhost already exists"
                bench use lms.localhost || true
                
                # Ensure payments app is installed on the site
                if [ -d "./apps/payments" ]; then
                    echo "Checking if Payments app is installed on site..."
                    bench --site lms.localhost list-apps | grep -q payments || {
                        echo "Installing Payments app on site..."
                        bench --site lms.localhost install-app payments || true
                    }
                fi
                
                # Ensure signup is enabled
                echo "Ensuring signup is enabled..."
                bench --site lms.localhost execute "frappe.db.set_single_value('Website Settings', 'disable_signup', 0)" || true
                # Set app name to VariPhi
                bench --site lms.localhost execute "frappe.db.set_single_value('Website Settings', 'app_name', 'VariPhi')" || true
                bench --site lms.localhost clear-cache || true
                
                # Check if assets need to be built
                # Assets are stored in sites/assets/assets.json
                if [ ! -f "$BENCH_DIR/sites/assets/assets.json" ] || [ ! -s "$BENCH_DIR/sites/assets/assets.json" ]; then
                    echo "⚠️  Assets not built or empty, building now..."
                    cd "$BENCH_DIR" || exit
                    set +e
                    bench build 2>&1
                    BUILD_EXIT=$?
                    set -e
                    if [ $BUILD_EXIT -ne 0 ]; then
                        echo "⚠️  Asset build had issues (exit code: $BUILD_EXIT)"
                        echo "   Retrying once..."
                        set +e
                        bench build 2>&1
                        BUILD_EXIT=$?
                        set -e
                        if [ $BUILD_EXIT -ne 0 ]; then
                            echo "❌ Asset build failed after retry. Site may have issues."
                            echo "   You can manually run 'bench build' later if needed."
                        else
                            echo "✓ Assets built successfully on retry"
                        fi
                    else
                        echo "✓ Assets built successfully"
                    fi
                else
                    echo "✓ Assets already built"
                fi
            fi
            
            echo "Starting bench..."
            bench start
            exit 0
        else
            echo "⚠️  Bench directory exists but bench commands don't work"
            echo "   Bench test output: $BENCH_TEST"
            BENCH_VALID=false
        fi
    else
        echo "⚠️  Bench directory exists but bench --version failed"
        echo "   Output: $BENCH_VERSION_OUTPUT"
        BENCH_VALID=false
    fi
else
    echo "⚠️  Bench directory missing required files:"
    echo "   - apps/frappe: $([ -d "$BENCH_DIR/apps/frappe" ] && echo 'exists' || echo 'MISSING')"
    echo "   - Procfile: $([ -f "$BENCH_DIR/Procfile" ] && echo 'exists' || echo 'MISSING')"
    echo "   - env/: $([ -d "$BENCH_DIR/env" ] && echo 'exists' || echo 'MISSING')"
    BENCH_VALID=false
fi

# If bench is not valid, create/recreate it
if [ "$BENCH_VALID" = false ]; then
    echo "Creating new bench..."
    
    # Check if bench directory already exists (even if incomplete)
    if [ -d "$BENCH_DIR" ]; then
        echo "✓ Bench directory already exists, checking structure..."
        # If bench exists but is incomplete, we'll try to use it anyway
        if [ ! -d "$BENCH_DIR/apps/frappe" ]; then
            echo "⚠️  Bench directory exists but apps/frappe is missing, attempting to initialize..."
        fi
    fi
    
    # Initialize bench (may fail if it already exists, but that's okay)
    # IMPORTANT: We must run bench init from /home/frappe, not from inside the bench directory
    # And we must use the full path to avoid creating nested directories
    cd /home/frappe || exit
    set +e  # Temporarily disable exit on error
    bench init --skip-redis-config-generation --skip-assets "$BENCH_DIR" 2>&1
    INIT_EXIT_CODE=$?
    set -e  # Re-enable exit on error
    
    # Check if bench directory exists (even if init failed)
    if [ ! -d "$BENCH_DIR" ]; then
        echo "❌ Error: Failed to create bench directory"
        exit 1
    fi
    
    # Bench directory exists, check if it's complete
    if [ $INIT_EXIT_CODE -eq 0 ]; then
        echo "✓ Bench init completed"
    else
        echo "⚠️  Bench init failed (likely because bench already exists)"
    fi
    
    # Check if bench init created a nested frappe-bench directory (common issue)
    NESTED_BENCH="$BENCH_DIR/frappe-bench"
    if [ -d "$NESTED_BENCH" ] && [ -d "$NESTED_BENCH/apps/frappe" ]; then
        echo "⚠️  Detected nested frappe-bench directory, moving contents up..."
        cd "$BENCH_DIR" || exit
        
        # Remove any existing empty or incomplete directories in parent that would conflict
        # This allows us to safely move nested contents
        set +e
        for dir in apps env sites config logs; do
            if [ -d "./$dir" ] && [ -z "$(ls -A "./$dir" 2>/dev/null)" ]; then
                echo "   Removing empty directory: $dir"
                rmdir "./$dir" 2>/dev/null || true
            fi
        done
        set -e
        
        # Use rsync or cp to merge directories (avoids "directory not empty" errors)
        set +e
        if command -v rsync >/dev/null 2>&1; then
            echo "   Using rsync to merge nested bench contents..."
            rsync -av "$NESTED_BENCH"/ "$BENCH_DIR"/ 2>&1 || {
                echo "   Rsync failed, trying cp..."
                shopt -s dotglob
                cp -a "$NESTED_BENCH"/* "$BENCH_DIR"/ 2>/dev/null || true
                shopt -u dotglob
            }
        else
            echo "   Using cp to merge nested bench contents..."
            shopt -s dotglob
            cp -a "$NESTED_BENCH"/* "$BENCH_DIR"/ 2>/dev/null || true
            shopt -u dotglob
        fi
        set -e
        
        # Fix ownership after copying
        chown -R frappe:frappe "$BENCH_DIR" 2>/dev/null || true
        
        # Remove the nested directory
        rm -rf "$NESTED_BENCH" 2>/dev/null || true
        echo "✓ Moved nested bench contents to correct location"
    fi
    
    # Ensure we're in the bench directory and create missing files
    cd "$BENCH_DIR" 2>/dev/null || {
        echo "⚠️  Cannot cd to bench directory, will try to fix..."
        mkdir -p "$BENCH_DIR" || exit 1
        cd "$BENCH_DIR" || exit 1
    }
    
    # Create Procfile if missing (bench init might not create it in some cases)
    if [ ! -f "./Procfile" ]; then
        echo "Creating Procfile..."
        cat > "./Procfile" << 'EOF'
web: bench serve --port 8000
socketio: node apps/frappe/socketio.js
worker: bench worker
watch: bench watch
schedule: bench schedule
frontend: cd apps/lms/frontend && yarn dev
EOF
        chown frappe:frappe ./Procfile 2>/dev/null || true
    fi
    
    # Ensure required directories exist
    mkdir -p ./sites ./config ./logs 2>/dev/null || true
    chown -R frappe:frappe ./sites ./config ./logs 2>/dev/null || true
    
    # Always verify frappe app exists, regardless of init exit code
    if [ ! -d "$BENCH_DIR/apps/frappe" ]; then
        echo "⚠️  Frappe app is missing after bench init, attempting to fix..."
        
        # Try to get frappe app - this might work even if bench seems invalid
        cd "$BENCH_DIR" 2>/dev/null || cd /home/frappe
        set +e
        echo "Attempting to get frappe app..."
        bench get-app frappe 2>&1
        GET_APP_EXIT_CODE=$?
        set -e
        
        if [ $GET_APP_EXIT_CODE -eq 0 ] && [ -d "$BENCH_DIR/apps/frappe" ]; then
            echo "✓ Successfully got frappe app"
        else
            # If we can't get frappe app, the bench is invalid
            # Since it's a mounted volume, we can't remove the directory itself,
            # but we can remove all contents inside it
            echo "⚠️  Could not get frappe app, bench is invalid. Cleaning bench directory contents..."
            cd /home/frappe || exit
            
            # Remove all contents inside the bench directory (not the directory itself)
            # This works even if it's a mounted volume
            set +e
            if [ -d "$BENCH_DIR" ]; then
                echo "Removing contents of invalid bench directory..."
                find "$BENCH_DIR" -mindepth 1 -delete 2>&1
                RM_EXIT_CODE=$?
            else
                RM_EXIT_CODE=0
            fi
            set -e
            
            if [ $RM_EXIT_CODE -ne 0 ]; then
                echo "⚠️  Could not clean bench directory contents"
                echo "   The bench directory may be a mounted volume with restricted permissions."
                echo "   Please run the following command to reset:"
                echo "   docker-compose down --volumes"
                echo "   Then restart with: docker-compose up"
                exit 1
            fi
            
            # Also check for and remove bench config files that might cause "already exists" error
            echo "Cleaning bench configuration files..."
            cd /home/frappe || exit
            rm -f .bench/config.json 2>/dev/null || true
            rm -rf .bench/frappe-bench 2>/dev/null || true
            
            echo "Cleaned bench directory and config, recreating from scratch..."
            
            # Since bench init detects the directory name, we'll initialize in a temp location
            # then move the contents to the actual location
            TEMP_BENCH_DIR="/home/frappe/frappe-bench-temp-$$"
            echo "Initializing bench in temporary location: $TEMP_BENCH_DIR"
            
            set +e
            bench init --skip-redis-config-generation --skip-assets --python "$(which python)" "$TEMP_BENCH_DIR" 2>&1
            INIT_EXIT_CODE=$?
            set -e
            
            if [ $INIT_EXIT_CODE -eq 0 ] && [ -d "$TEMP_BENCH_DIR/apps/frappe" ]; then
                echo "✓ Bench initialized successfully in temp location"
                echo "Verifying temp bench structure..."
                ls -la "$TEMP_BENCH_DIR" | head -15 || true
                
                # Setup requirements to create env directory
                echo "Setting up requirements in temp bench..."
                cd "$TEMP_BENCH_DIR" || exit
                set +e
                bench setup requirements 2>&1
                SETUP_EXIT=$?
                set -e
                if [ $SETUP_EXIT -eq 0 ] && [ -d "$TEMP_BENCH_DIR/env" ]; then
                    echo "✓ Requirements setup completed, env directory created"
                else
                    echo "⚠️  Requirements setup had issues, but continuing..."
                fi
                
                echo "Moving bench contents to final location..."
                
                # Ensure target directory exists
                mkdir -p "$BENCH_DIR" 2>/dev/null || true
                
                # The bench directory is a volume mount, so it might be owned by root initially
                # We need to ensure we can write to it. If we can't, we'll need to handle it differently
                if [ -d "$BENCH_DIR" ] && [ ! -w "$BENCH_DIR" ]; then
                    echo "⚠️  Bench directory is not writable. This is likely a volume permission issue."
                    echo "   The volume may have been created with root ownership."
                    echo "   Attempting to work around this..."
                    
                    # Try to create a subdirectory we can write to
                    # Or, we could copy to a location we can write to and then move
                    # For now, let's try to proceed and see if the copy works despite permissions
                fi
                
                # Ensure target is empty
                if [ -d "$BENCH_DIR" ] && [ "$(ls -A "$BENCH_DIR" 2>/dev/null)" ]; then
                    echo "Clearing target directory..."
                    find "$BENCH_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
                fi
                
                # Move all contents from temp to final location using rsync for reliability
                echo "Copying bench contents..."
                if command -v rsync >/dev/null 2>&1; then
                    rsync -av "$TEMP_BENCH_DIR"/ "$BENCH_DIR"/ || {
                        echo "Rsync failed, trying with cp..."
                        # Fallback to cp with proper permissions
                        shopt -s dotglob
                        cp -a "$TEMP_BENCH_DIR"/* "$BENCH_DIR"/ 2>/dev/null || true
                        shopt -u dotglob
                    }
                else
                    # Use cp with dotglob to include hidden files, preserve attributes
                    shopt -s dotglob
                    cp -a "$TEMP_BENCH_DIR"/* "$BENCH_DIR"/ 2>/dev/null || true
                    shopt -u dotglob
                fi
                
                # Fix ownership after copying
                echo "Fixing ownership of copied files..."
                chown -R frappe:frappe "$BENCH_DIR" 2>/dev/null || true
                
                # Verify essential bench files exist and create missing ones
                echo "Verifying bench structure..."
                
                # Check if env directory was copied (critical for bench to work)
                if [ ! -d "$BENCH_DIR/env" ]; then
                    echo "⚠️  env directory missing after copy, this is critical!"
                    echo "   Attempting to recreate it..."
                    cd "$BENCH_DIR" || exit
                    set +e
                    bench setup requirements 2>&1
                    SETUP_EXIT=$?
                    set -e
                    if [ $SETUP_EXIT -ne 0 ]; then
                        echo "⚠️  bench setup failed, env directory may be missing"
                    fi
                fi
                
                # Ensure sites directory exists
                mkdir -p "$BENCH_DIR/sites" 2>/dev/null || true
                chown frappe:frappe "$BENCH_DIR/sites" 2>/dev/null || true
                
                # Check if Procfile exists, if not create it
                if [ ! -f "$BENCH_DIR/Procfile" ]; then
                    echo "⚠️  Procfile missing, creating it..."
                    cat > "$BENCH_DIR/Procfile" << 'EOF'
web: bench serve --port 8000
socketio: node apps/frappe/socketio.js
worker: bench worker
watch: bench watch
schedule: bench schedule
frontend: cd apps/lms/frontend && yarn dev
EOF
                    chown frappe:frappe "$BENCH_DIR/Procfile" 2>/dev/null || true
                fi
                
                # Ensure config directory exists
                mkdir -p "$BENCH_DIR/config" 2>/dev/null || true
                chown frappe:frappe "$BENCH_DIR/config" 2>/dev/null || true
                
                # Ensure logs directory exists
                mkdir -p "$BENCH_DIR/logs" 2>/dev/null || true
                chown frappe:frappe "$BENCH_DIR/logs" 2>/dev/null || true
                
                # List what was copied for debugging
                echo "Bench directory contents after copy:"
                ls -la "$BENCH_DIR" 2>/dev/null | head -20 || true
                echo "Checking for env directory:"
                if [ -d "$BENCH_DIR/env" ]; then
                    echo "✓ env directory exists"
                    ls -la "$BENCH_DIR/env" 2>/dev/null | head -5 || true
                else
                    echo "✗ env directory NOT FOUND - this is critical!"
                    echo "   Attempting to create it..."
                    cd "$BENCH_DIR" || exit
                    set +e
                    bench setup requirements 2>&1
                    SETUP_EXIT=$?
                    set -e
                    if [ $SETUP_EXIT -eq 0 ] && [ -d "./env" ]; then
                        echo "✓ env directory created successfully"
                    else
                        echo "⚠️  Could not create env directory, bench may not work properly"
                    fi
                fi
                
                # Verify frappe app and env directory were moved
                if [ -d "$BENCH_DIR/apps/frappe" ] && [ -d "$BENCH_DIR/env" ]; then
                    echo "✓ Bench contents moved successfully (frappe app and env directory present)"
                    # Remove temp directory
                    rm -rf "$TEMP_BENCH_DIR" 2>/dev/null || true
                    INIT_EXIT_CODE=0
                elif [ -d "$BENCH_DIR/apps/frappe" ]; then
                    echo "⚠️  Frappe app moved but env directory missing"
                    echo "   This might cause bench commands to fail"
                    echo "   Attempting to create env directory..."
                    cd "$BENCH_DIR" || exit
                    # Try to run bench setup to create env
                    set +e
                    bench setup requirements 2>&1 || {
                        echo "⚠️  Could not setup env, but continuing..."
                    }
                    set -e
                    rm -rf "$TEMP_BENCH_DIR" 2>/dev/null || true
                    INIT_EXIT_CODE=0
                else
                    echo "⚠️  Frappe app not found after move, checking what was moved..."
                    ls -la "$BENCH_DIR" 2>/dev/null || true
                    ls -la "$BENCH_DIR/apps" 2>/dev/null || true
                    # Try to copy frappe app directly
                    if [ -d "$TEMP_BENCH_DIR/apps/frappe" ]; then
                        echo "Attempting to copy frappe app directly..."
                        # Create apps directory - if this fails, the volume has permission issues
                        if mkdir -p "$BENCH_DIR/apps" 2>/dev/null; then
                            cp -r "$TEMP_BENCH_DIR/apps/frappe" "$BENCH_DIR/apps/" 2>/dev/null || true
                        else
                            echo "❌ Cannot create apps directory due to permissions"
                            echo "   The bench volume is owned by root. You need to fix the volume permissions."
                            echo "   Run this command to fix it:"
                            echo "   docker-compose down"
                            echo "   docker run --rm -v lms_bench-data:/data alpine chown -R 1000:1000 /data"
                            echo "   docker-compose up"
                            INIT_EXIT_CODE=1
                        fi
                    fi
                    rm -rf "$TEMP_BENCH_DIR" 2>/dev/null || true
                    # Check again
                    if [ -d "$BENCH_DIR/apps/frappe" ]; then
                        INIT_EXIT_CODE=0
                    else
                        INIT_EXIT_CODE=1
                    fi
                fi
            else
                echo "⚠️  Failed to initialize bench in temp location"
                # Clean up temp directory if it exists
                rm -rf "$TEMP_BENCH_DIR" 2>/dev/null || true
            fi
            
            if [ $INIT_EXIT_CODE -ne 0 ]; then
                echo "❌ Error: Bench init failed after cleanup"
                echo "   This might be a network issue or bench configuration problem."
                exit 1
            fi
            
            # Verify frappe app was created this time
            if [ ! -d "$BENCH_DIR/apps/frappe" ]; then
                echo "❌ Error: Bench created but frappe app is still missing"
                echo "   This might be a network issue. Check your internet connection."
                echo "   Try: docker-compose down --volumes"
                exit 1
            fi
            echo "✓ Bench recreated successfully with frappe app"
        fi
    fi
    
    # Final verification - ensure bench has frappe app
    if [ ! -d "$BENCH_DIR/apps/frappe" ]; then
        echo "❌ Error: Bench is still missing frappe app after all recovery attempts"
        echo "   You may need to remove the bench directory and try again:"
        echo "   docker-compose down --volumes"
        exit 1
    fi
    
    # Now ensure the bench directory is complete with all required files
    echo "✓ Bench directory exists, ensuring it's complete..."
    
    # Ensure we're in the bench directory
    cd "$BENCH_DIR" || {
        echo "❌ Error: Cannot change to bench directory: $BENCH_DIR"
        exit 1
    }
    echo "Current directory: $(pwd)"
    
    # Check what's actually in the bench directory
    echo "Bench directory contents:"
    ls -la . 2>/dev/null || true
    echo "Apps directory contents:"
    ls -la ./apps 2>/dev/null || true
    
    # Ensure frappe app exists
    if [ ! -d "./apps/frappe" ]; then
        echo "⚠️  Frappe app is missing, attempting to get it..."
        bench get-app frappe || {
            echo "❌ Error: Could not get frappe app"
            exit 1
        }
    fi
    
    # Ensure Procfile exists - create it if missing
    if [ ! -f "./Procfile" ]; then
        echo "⚠️  Procfile is missing, creating it..."
        cat > "./Procfile" << 'EOF'
web: bench serve --port 8000
socketio: node apps/frappe/socketio.js
worker: bench worker
watch: bench watch
schedule: bench schedule
frontend: cd apps/lms/frontend && yarn dev
EOF
        chown frappe:frappe ./Procfile 2>/dev/null || true
    fi
    
    # Ensure other required directories exist
    mkdir -p ./sites ./config ./logs 2>/dev/null || true
    chown -R frappe:frappe ./sites ./config ./logs 2>/dev/null || true
    
    # Final verification
    if [ ! -f "./Procfile" ] || [ ! -d "./apps/frappe" ]; then
        echo "❌ Error: Bench directory is still not valid after fixes."
        echo "   Procfile exists: $([ -f ./Procfile ] && echo 'yes' || echo 'no')"
        echo "   Frappe app exists: $([ -d ./apps/frappe ] && echo 'yes' || echo 'no')"
        exit 1
    fi
    
    # Check if env directory exists (Python virtual environment - required for bench)
    if [ ! -d "./env" ]; then
        echo "⚠️  env directory missing, this is CRITICAL for bench to work"
        echo "   Creating Python virtual environment..."
        cd "$BENCH_DIR" || exit
        
        # First ensure we have frappe app installed
        if [ ! -d "./apps/frappe" ]; then
            echo "   Frappe app is also missing, getting it first..."
            bench get-app frappe || {
                echo "❌ Error: Could not get frappe app"
                exit 1
            }
        fi
        
        # Create the virtual environment manually first
        echo "   Creating virtual environment with python -m venv..."
        set +e
        python3 -m venv ./env 2>&1
        VENV_EXIT=$?
        set -e
        
        if [ $VENV_EXIT -ne 0 ] || [ ! -d "./env" ]; then
            echo "❌ Error: Could not create virtual environment"
            echo "   Tried: python3 -m venv ./env"
            echo "   Exit code: $VENV_EXIT"
            echo ""
            echo "   Please run: docker-compose down --volumes"
            echo "   Then: docker-compose up"
            exit 1
        fi
        
        echo "✓ Virtual environment created"
        
        # Now setup the bench configuration first (this is needed for bench to recognize the directory)
        echo "   Setting up bench configuration..."
        set +e
        bench setup config 2>&1 || true
        set -e
        
        # Now setup the requirements
        echo "   Installing requirements..."
        set +e
        bench setup requirements 2>&1
        SETUP_EXIT=$?
        set -e
        
        if [ $SETUP_EXIT -ne 0 ]; then
            echo "⚠️  bench setup requirements had issues (exit code: $SETUP_EXIT)"
            echo "   But env directory exists, continuing..."
        else
            echo "✓ Requirements installed successfully"
        fi
        
        # Verify bench now recognizes the directory
        echo "   Verifying bench recognizes this directory..."
        set +e
        BENCH_VERIFY=$(cd "$BENCH_DIR" && bench list-apps 2>&1)
        BENCH_VERIFY_EXIT=$?
        set -e
        
        if [ $BENCH_VERIFY_EXIT -eq 0 ]; then
            echo "✓ Bench now recognizes this directory"
        else
            echo "⚠️  Bench still doesn't recognize directory, but continuing..."
            echo "   Output: $BENCH_VERIFY"
        fi
        
        if [ ! -d "./env" ]; then
            echo "❌ Error: env directory still missing after setup"
            exit 1
        fi
    fi
    
    # Verify bench recognizes this directory by testing a command
    echo "Verifying bench directory is valid..."
    cd "$BENCH_DIR" || exit
    
    # First, ensure bench configuration is set up
    if [ ! -f "./sites/common_site_config.json" ]; then
        echo "   Setting up bench configuration..."
        set +e
        bench setup config 2>&1 || true
        set -e
    fi
    
    set +e
    BENCH_TEST=$(bench --version 2>&1)
    BENCH_TEST_EXIT=$?
    set -e
    
    if [ $BENCH_TEST_EXIT -ne 0 ]; then
        echo "⚠️  Bench --version failed, but this might be okay if bench is still initializing"
        echo "   Output: $BENCH_TEST"
    fi
    
    # Test a bench command that requires being in a valid bench directory
    # This is the real test - if this works, bench recognizes the directory
    set +e
    BENCH_LIST=$(bench list-apps 2>&1)
    BENCH_LIST_EXIT=$?
    set -e
    
    if [ $BENCH_LIST_EXIT -ne 0 ]; then
        echo "⚠️  Bench list-apps failed - bench may not fully recognize this directory yet"
        echo "   Output: $BENCH_LIST"
        echo ""
        echo "   This might be okay if requirements are still installing."
        echo "   Checking if we can continue anyway..."
        
        # Check if the essential components exist
        if [ -d "./env" ] && [ -d "./apps/frappe" ] && [ -f "./Procfile" ]; then
            echo "✓ Essential components exist, continuing despite warning..."
        else
            echo "❌ Error: Essential components missing"
            echo "   - env/: $([ -d ./env ] && echo 'exists' || echo 'MISSING')"
            echo "   - apps/frappe/: $([ -d ./apps/frappe ] && echo 'exists' || echo 'MISSING')"
            echo "   - Procfile: $([ -f ./Procfile ] && echo 'exists' || echo 'MISSING')"
            echo ""
            echo "   Please run: docker-compose down --volumes"
            echo "   Then: docker-compose up"
            exit 1
        fi
    else
        echo "✓ Bench recognizes this directory and commands work"
    fi
    
    echo "✓ Bench is ready"
    
    # Verify we're still in the bench directory
    if [ "$(pwd)" != "$BENCH_DIR" ]; then
        echo "⚠️  Not in bench directory, changing to it..."
        cd "$BENCH_DIR" || exit
    fi
    
    # Use containers instead of localhost
    # These commands must be run from within the bench directory
    echo "Configuring bench for Docker containers..."
    bench set-mariadb-host mariadb || true
    bench set-redis-cache-host redis://redis:6379 || true
    bench set-redis-queue-host redis://redis:6379 || true
    bench set-redis-socketio-host redis://redis:6379 || true
    
    # Remove redis from Procfile (we use Docker Redis container)
    # Keep watch and schedule for development
    if [ -f "./Procfile" ]; then
        sed -i '/redis_cache/d' ./Procfile || true
        sed -i '/redis_queue/d' ./Procfile || true
        # Ensure watch and schedule are in Procfile (add if missing)
        if ! grep -q "^watch:" ./Procfile; then
            echo "watch: bench watch" >> ./Procfile
        fi
        if ! grep -q "^schedule:" ./Procfile; then
            echo "schedule: bench schedule" >> ./Procfile
        fi
        # Add frontend dev server if not present (only if frontend directory exists)
        if ! grep -q "^frontend:" ./Procfile; then
            if [ -d "./apps/lms/frontend" ] && command -v yarn >/dev/null 2>&1; then
                echo "frontend: cd apps/lms/frontend && yarn dev" >> ./Procfile
            fi
        fi
    fi
    
    # Get LMS app from workspace or install it
    if [ -d "$WORKSPACE_DIR/apps/lms" ] && [ -f "$WORKSPACE_DIR/apps/lms/pyproject.toml" ]; then
        echo "Using LMS app from workspace..."
        # Check if app is already in bench
        if [ ! -d "./apps/lms" ]; then
            # Use bench get-app with local path to properly set up the app
            bench get-app lms "$WORKSPACE_DIR/apps/lms" || {
                echo "Copying LMS app from workspace..."
                cp -r "$WORKSPACE_DIR/apps/lms" ./apps/
            }
        else
            echo "LMS app already exists in bench, skipping..."
        fi
    else
        echo "Getting LMS app from repository..."
        if [ ! -d "./apps/lms" ]; then
            bench get-app lms
        else
            echo "LMS app already exists in bench, skipping..."
        fi
    fi
    
    # Get Payments app from workspace or install it (required for Payment Gateways)
    if [ -d "$WORKSPACE_DIR/apps/payments" ] && [ -f "$WORKSPACE_DIR/apps/payments/pyproject.toml" ]; then
        echo "Using Payments app from workspace..."
        # Check if app is already in bench
        if [ ! -d "./apps/payments" ]; then
            # Use bench get-app with local path to properly set up the app
            bench get-app payments "$WORKSPACE_DIR/apps/payments" || {
                echo "Copying Payments app from workspace..."
                cp -r "$WORKSPACE_DIR/apps/payments" ./apps/
            }
        else
            echo "Payments app already exists in bench, skipping..."
        fi
    else
        echo "Getting Payments app from repository..."
        if [ ! -d "./apps/payments" ]; then
            bench get-app payments
        else
            echo "Payments app already exists in bench, skipping..."
        fi
    fi
    
    # Create site - ensure we're in bench directory
    cd "$BENCH_DIR" || exit
    echo "Creating site lms.localhost..."
    echo "Current directory before new-site: $(pwd)"
    echo "Checking if bench is valid:"
    ls -la . | head -10 || true
    
    # Check if site already exists
    if [ ! -d "./sites/lms.localhost" ]; then
        bench new-site lms.localhost \
            --force \
            --mariadb-root-password 123 \
            --admin-password admin \
            --no-mariadb-socket || {
            echo "⚠️  Site creation failed, but continuing..."
        }
    else
        echo "✓ Site lms.localhost already exists"
    fi
    
    # Install app - ensure we're in bench directory
    cd "$BENCH_DIR" || exit
    if [ -d "./sites/lms.localhost" ]; then
        # Ensure dependencies are installed before building
        if [ -f "/home/frappe/setup-dependencies.sh" ]; then
            echo "Setting up dependencies before building assets..."
            bash /home/frappe/setup-dependencies.sh || {
                echo "⚠️  Dependency setup had issues, but continuing..."
            }
        fi
        
        # Ensure frontend dependencies are installed for dev server
        if [ -d "./apps/lms/frontend" ]; then
            echo "Installing frontend dependencies for dev server..."
            cd ./apps/lms/frontend || true
            if [ -f "yarn.lock" ] && command -v yarn >/dev/null 2>&1; then
                yarn install --frozen-lockfile || {
                    echo "⚠️  Frontend dependency install had issues, trying without frozen lockfile..."
                    yarn install || echo "⚠️  Frontend dependencies may be incomplete"
                }
            elif [ -f "package.json" ] && command -v npm >/dev/null 2>&1; then
                npm ci || {
                    echo "⚠️  Frontend dependency install had issues, trying npm install..."
                    npm install || echo "⚠️  Frontend dependencies may be incomplete"
                }
            fi
            cd "$BENCH_DIR" || exit
        fi
        
        # Install payments app first (required for Payment Gateways module)
        if [ -d "./apps/payments" ]; then
            echo "Installing Payments app (required for Payment Gateways)..."
            bench --site lms.localhost install-app payments || true
        fi
        
        bench --site lms.localhost install-app lms || true
        bench --site lms.localhost set-config developer_mode 1 || true
        
        # Enable signup (required for sign-up option to show on login page)
        echo "Enabling signup..."
        bench --site lms.localhost execute "frappe.db.set_single_value('Website Settings', 'disable_signup', 0)" || true
        # Set app name to VariPhi
        bench --site lms.localhost execute "frappe.db.set_single_value('Website Settings', 'app_name', 'VariPhi')" || true
        
        bench --site lms.localhost clear-cache || true
        bench use lms.localhost || true
        
        # Build assets after app installation
        # This is critical - without assets, the site will fail with AttributeError
        echo "Building assets (required for site to work)..."
        cd "$BENCH_DIR" || exit
        set +e
        bench build 2>&1
        BUILD_EXIT=$?
        set -e
        if [ $BUILD_EXIT -ne 0 ]; then
            echo "⚠️  Asset build had issues (exit code: $BUILD_EXIT)"
            echo "   Retrying once..."
            set +e
            bench build 2>&1
            BUILD_EXIT=$?
            set -e
            if [ $BUILD_EXIT -ne 0 ]; then
                echo "❌ Asset build failed after retry (exit code: $BUILD_EXIT)"
                echo "   This may cause errors when accessing the site"
                echo "   You can try running 'bench build' manually later"
            else
                echo "✓ Assets built successfully on retry"
            fi
        else
            echo "✓ Assets built successfully"
        fi
    else
        echo "⚠️  Site lms.localhost does not exist, skipping app installation"
    fi
    
    echo "Starting bench..."
    cd "$BENCH_DIR" || exit
    bench start
fi
