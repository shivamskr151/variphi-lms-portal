# Use official Frappe Bench image from Docker Hub
FROM frappe/bench:latest

# Set working directory
WORKDIR /home/frappe

# Install additional system dependencies
USER root
RUN apt-get update && apt-get install -y \
    git \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Switch to frappe user for file operations
USER frappe

# Copy entire frappe-bench structure into the container
# This includes apps, sites, config, etc.
# Note: Source code is copied here, but will be overridden by volume mounts in development
COPY --chown=frappe:frappe . /home/frappe/frappe-bench

# Ensure init script is executable (it should be included in the copy above)
RUN if [ -f "/home/frappe/frappe-bench/apps/lms/docker/docker-init.sh" ]; then \
        chmod +x /home/frappe/frappe-bench/apps/lms/docker/docker-init.sh; \
    fi

# Set working directory to bench
WORKDIR /home/frappe/frappe-bench

# Note: Dependencies will be installed at runtime by the init script
# This allows the bench environment to be properly set up first

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV SHELL=/bin/bash
ENV BENCH_NAME=frappe-bench
ENV MARIADB_HOST=mariadb
ENV MARIADB_ROOT_PASSWORD=123

# Expose ports
EXPOSE 8000 9000 5173 6787

# Default command - can be overridden in docker-compose
# Script will be available via volume mount in development
CMD ["bash", "/home/frappe/frappe-bench/apps/lms/docker/docker-init.sh"]
