#!/usr/bin/env bash

# Default settings
CONTAINER_NAME="devdb"
VOLUME_NAME="devdb_data"
IMAGE_NAME="postgres:latest"
HOST_PORT=5432

# Usage function
usage() {
  cat << EOF
Usage: $0 [options]

Options:
  -r, --reset    Remove existing container and volume before creating
  -h, --help     Show this help message and exit
EOF
  exit 0
}

# Parse flags
do_reset=false
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -r|--reset)
      do_reset=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Reset container and volume if requested
if [ "$do_reset" = true ]; then
  echo "==> Removing existing container and volume..."
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  docker volume rm "$VOLUME_NAME" 2>/dev/null || true
fi

# Create named volume if not exists
docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1 || \
  docker volume create "$VOLUME_NAME"

# Function to check if port is in use
check_port_conflict() {
  local port_in_use=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep ":$HOST_PORT->" | grep -v "^$CONTAINER_NAME")
  if [ -n "$port_in_use" ]; then
    echo "ERROR: Port $HOST_PORT is already in use by another container:"
    echo "$port_in_use"
    echo ""
    echo "Solutions:"
    echo "  1. Stop the conflicting container"
    echo "  2. Use 'devdb --reset' to remove and recreate"
    echo "  3. Modify the script to use a different port"
    exit 1
  fi
}

# Check container status and act accordingly
if docker ps -q -f name="^${CONTAINER_NAME}$" | grep -q .; then
  echo "==> PostgreSQL container '$CONTAINER_NAME' is already running"
  show_ready_message=false
elif docker ps -aq -f name="^${CONTAINER_NAME}$" | grep -q .; then
  echo "==> Starting existing PostgreSQL container '$CONTAINER_NAME'"
  docker start "$CONTAINER_NAME" >/dev/null
  show_ready_message=true
else
  # Check for port conflicts before creating new container
  check_port_conflict
  echo "==> Creating and starting PostgreSQL container '$CONTAINER_NAME'"
  if ! docker run -d \
    --restart unless-stopped \
    -p "127.0.0.1:$HOST_PORT:5432" \
    --name "$CONTAINER_NAME" \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -v "$VOLUME_NAME":/var/lib/postgresql/data \
    "$IMAGE_NAME" >/dev/null; then
    echo "ERROR: Failed to start container. Port $HOST_PORT might be in use by a non-Docker process."
    echo "Try: sudo lsof -i :$HOST_PORT"
    exit 1
  fi
  show_ready_message=true
fi

# Show ready message only when container was started/created
if [ "$show_ready_message" = true ]; then
  # Wait a moment for container to be ready
  sleep 1
  echo
  echo "Your development database is ready!"
  echo "Add this to your environment variables:"
  echo
  echo "  export DATABASE_URL='postgresql://postgres@127.0.0.1:$HOST_PORT/postgres'"
  echo
fi


