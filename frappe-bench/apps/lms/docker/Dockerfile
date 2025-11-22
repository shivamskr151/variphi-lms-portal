FROM frappe/bench:latest

# Set working directory
WORKDIR /home/frappe

# Install system dependencies if needed
USER root
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create workspace directory with proper permissions
RUN mkdir -p /workspace && \
    chown -R frappe:frappe /workspace

# Install gosu for user switching (available in Debian)
RUN apt-get update && apt-get install -y \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Copy entrypoint and initialization scripts
COPY apps/lms/docker/entrypoint.sh /entrypoint.sh
COPY apps/lms/docker/init.sh /home/frappe/init.sh
COPY setup-dependencies.sh /home/frappe/setup-dependencies.sh
RUN chmod +x /entrypoint.sh /home/frappe/init.sh /home/frappe/setup-dependencies.sh && \
    chown frappe:frappe /home/frappe/init.sh /home/frappe/setup-dependencies.sh

# Keep as root for entrypoint to fix permissions
# USER frappe will be handled by entrypoint

# Set environment variables
ENV SHELL=/bin/bash
ENV PYTHONUNBUFFERED=1

# Set working directory for commands
WORKDIR /workspace

# Use entrypoint to fix permissions
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash", "/home/frappe/init.sh"]

