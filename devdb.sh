#!/usr/bin/env bash

# Default settings
CONTAINER_NAME="devdb"
VOLUME_NAME="devdb_data"
IMAGE_NAME="postgres:latest"
HOST_PORT=5432
DB_NAME="devdb"

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

# Check if container already exists
if docker ps -a --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
  # Container exists, check if it's running
  if docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "==> PostgreSQL container '$CONTAINER_NAME' is already running"
  else
    echo "==> Starting existing PostgreSQL container '$CONTAINER_NAME'"
    docker start "$CONTAINER_NAME"
  fi
else
  # Container doesn't exist, create it
  echo "==> Creating and starting PostgreSQL container '$CONTAINER_NAME'"
  docker run -d \
    --restart unless-stopped \
    -p "127.0.0.1:$HOST_PORT:5432" \
    --name "$CONTAINER_NAME" \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -v "$VOLUME_NAME":/var/lib/postgresql/data \
    "$IMAGE_NAME"
fi

# Construct and output DATABASE_URL for env
DATABASE_URL="postgresql://postgres@127.0.0.1:$HOST_PORT/$DB_NAME"

echo
echo "Your development database is ready!"
echo "Add this to your environment variables:"
echo
# Export suggestion
echo "  export DATABASE_URL='$DATABASE_URL'"


