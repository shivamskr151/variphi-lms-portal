# Docker Troubleshooting Guide

## Common Issues and Solutions

### 1. "Cannot connect to the Docker daemon"

**Error:**
```
Cannot connect to the Docker daemon at unix:///Users/shivam/.docker/run/docker.sock. 
Is the docker daemon running?
```

**Solution:**

**On macOS:**
1. Open Docker Desktop from Applications
2. Wait for the whale icon to appear in the menu bar (top right)
3. Wait until it shows "Docker Desktop is running"
4. Try your command again

**Quick fix using helper script:**
```bash
cd frappe-bench/apps/lms/docker
./docker-check.sh
```

**Manual start:**
```bash
open -a Docker
# Wait 30-60 seconds for Docker to fully start
```

**On Linux:**
```bash
sudo systemctl start docker
sudo systemctl enable docker  # Enable auto-start on boot
```

### 2. Docker Desktop Won't Start

**Symptoms:**
- Docker Desktop app opens but doesn't start
- Whale icon doesn't appear in menu bar
- Error messages in Docker Desktop

**Solutions:**

1. **Check system requirements:**
   - macOS: macOS 10.15 or later
   - At least 4GB RAM available
   - Virtualization enabled in BIOS (if applicable)

2. **Restart Docker Desktop:**
   ```bash
   # Quit Docker Desktop completely
   osascript -e 'quit app "Docker"'
   # Wait a few seconds
   open -a Docker
   ```

3. **Reset Docker Desktop:**
   - Open Docker Desktop
   - Go to Settings → Troubleshoot
   - Click "Reset to factory defaults" (this will remove all containers and images)

4. **Check Docker Desktop logs:**
   ```bash
   # View Docker Desktop logs
   tail -f ~/Library/Containers/com.docker.docker/Data/log/vm/dockerd.log
   ```

### 3. Port Already in Use

**Error:**
```
Error: bind: address already in use
```

**Solution:**

Check what's using the port:
```bash
# Check port 8000
lsof -i :8000

# Check port 9000
lsof -i :9000

# Check port 3307 (Docker MariaDB)
lsof -i :3307

# Check port 6380 (Docker Redis)
lsof -i :6380
```

Stop the conflicting service or change the port in `docker-compose.yml`.

### 4. Environment Variables Not Loading

**Issue:** Docker containers not using values from `.env` file

**Solution:**

1. **Use the helper script** (automatically loads .env):
   ```bash
   ./docker-compose.sh build
   ./docker-compose.sh up
   ```

2. **Or manually load .env:**
   ```bash
   cd frappe-bench
   source .env
   cd apps/lms/docker
   docker-compose build
   ```

3. **Or use env_file in docker-compose.yml:**
   ```yaml
   services:
     frappe:
       env_file:
         - ../../../.env
   ```

### 5. Build Fails with "No space left on device"

**Error:**
```
Error: no space left on device
```

**Solution:**

1. **Clean up Docker:**
   ```bash
   # Remove unused containers, networks, images
   docker system prune -a
   
   # Remove unused volumes
   docker volume prune
   ```

2. **Check disk space:**
   ```bash
   df -h
   ```

3. **Increase Docker Desktop disk space:**
   - Open Docker Desktop
   - Go to Settings → Resources → Advanced
   - Increase "Disk image size"

### 6. Container Keeps Restarting

**Symptoms:**
- Container starts then immediately stops
- Status shows "Restarting" in `docker ps`

**Solution:**

1. **Check container logs:**
   ```bash
   docker-compose logs frappe
   docker-compose logs mariadb
   docker-compose logs redis
   ```

2. **Check container status:**
   ```bash
   docker ps -a
   docker inspect <container_name>
   ```

3. **Common causes:**
   - Database connection failed
   - Missing environment variables
   - Port conflicts
   - Insufficient resources

### 7. "Permission denied" Errors

**Error:**
```
Permission denied: /var/run/docker.sock
```

**Solution:**

**On Linux:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and log back in
```

**On macOS:** Usually not needed, but if you see this:
```bash
# Reset Docker Desktop permissions
# Docker Desktop → Settings → Resources → Reset
```

### 8. Slow Performance

**Symptoms:**
- Containers start slowly
- Application is slow to respond
- High CPU/memory usage

**Solutions:**

1. **Increase Docker Desktop resources:**
   - Docker Desktop → Settings → Resources
   - Increase CPU and Memory allocation

2. **Use Docker volumes efficiently:**
   - Avoid mounting large directories
   - Use named volumes for data that doesn't need hot-reload

3. **Check for resource conflicts:**
   ```bash
   # Check Docker resource usage
   docker stats
   ```

## Quick Diagnostic Commands

```bash
# Check Docker version
docker --version

# Check Docker is running
docker info

# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Check Docker Compose version
docker-compose --version

# View Docker system information
docker system df

# Check Docker logs
docker-compose logs

# Check specific service logs
docker-compose logs frappe
docker-compose logs mariadb
docker-compose logs redis
```

## Getting Help

If you're still having issues:

1. **Check Docker Desktop status:**
   - Look for the whale icon in menu bar
   - Click it to see Docker Desktop status

2. **View detailed logs:**
   ```bash
   docker-compose logs --tail=100 -f
   ```

3. **Reset everything:**
   ```bash
   docker-compose down -v
   docker system prune -a
   # Then rebuild
   ./docker-compose.sh build
   ./docker-compose.sh up
   ```

4. **Check the main project README:**
   - See `frappe-bench/README.md` for general setup
   - See `frappe-bench/ENV_SETUP.md` for environment configuration

