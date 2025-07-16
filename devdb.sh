#!/usr/bin/env bash

# Default settings
CONTAINER_NAME="devdb"
VOLUME_NAME="devdb_data"
IMAGE_NAME="postgres:latest"
HOST_PORT=5432

# Redis settings
REDIS_CONTAINER_NAME="devdb-redis"
REDIS_VOLUME_NAME="devdb_redis_data"
REDIS_IMAGE_NAME="redis:latest"
REDIS_HOST_PORT=6379
REDIS_INSIGHT_CONTAINER_NAME="devdb-redis-insight"
REDIS_INSIGHT_IMAGE_NAME="redis/redisinsight:latest"
REDIS_INSIGHT_HOST_PORT=5540

# Usage function
usage() {
  cat << EOF
Usage: $0 [options]

Options:
  -r, --reset    Remove existing container and volume before creating
  --redis        Set up Redis instead of PostgreSQL (includes RedisInsight on port 5540)
  -h, --help     Show this help message and exit
EOF
  exit 0
}

# Parse flags
do_reset=false
use_redis=false
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -r|--reset)
      do_reset=true
      shift
      ;;
    --redis)
      use_redis=true
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
  if [ "$use_redis" = true ]; then
    echo "==> Removing existing Redis containers and volume..."
    docker rm -f "$REDIS_CONTAINER_NAME" 2>/dev/null || true
    docker rm -f "$REDIS_INSIGHT_CONTAINER_NAME" 2>/dev/null || true
    docker volume rm "$REDIS_VOLUME_NAME" 2>/dev/null || true
  else
    echo "==> Removing existing container and volume..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    docker volume rm "$VOLUME_NAME" 2>/dev/null || true
  fi
fi

# Create named volume if not exists
if [ "$use_redis" = true ]; then
  docker volume inspect "$REDIS_VOLUME_NAME" >/dev/null 2>&1 || \
    docker volume create "$REDIS_VOLUME_NAME"
else
  docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1 || \
    docker volume create "$VOLUME_NAME"
fi

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

# Function to check if Redis ports are in use
check_redis_port_conflict() {
  local redis_port_in_use=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep ":$REDIS_HOST_PORT->" | grep -v "^$REDIS_CONTAINER_NAME")
  if [ -n "$redis_port_in_use" ]; then
    echo "ERROR: Redis port $REDIS_HOST_PORT is already in use by another container:"
    echo "$redis_port_in_use"
    exit 1
  fi
  
  local insight_port_in_use=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep ":$REDIS_INSIGHT_HOST_PORT->" | grep -v "^$REDIS_INSIGHT_CONTAINER_NAME")
  if [ -n "$insight_port_in_use" ]; then
    echo "ERROR: RedisInsight port $REDIS_INSIGHT_HOST_PORT is already in use by another container:"
    echo "$insight_port_in_use"
    exit 1
  fi
}

# Function to setup Redis containers
setup_redis() {
  # Always wipe data if Redis containers exist
  if docker ps -aq -f name="^${REDIS_CONTAINER_NAME}$" | grep -q .; then
    echo "==> Removing existing Redis container and data..."
    docker rm -f "$REDIS_CONTAINER_NAME" 2>/dev/null || true
    docker volume rm "$REDIS_VOLUME_NAME" 2>/dev/null || true
    docker volume create "$REDIS_VOLUME_NAME"
  fi
  
  if docker ps -aq -f name="^${REDIS_INSIGHT_CONTAINER_NAME}$" | grep -q .; then
    echo "==> Removing existing RedisInsight container..."
    docker rm -f "$REDIS_INSIGHT_CONTAINER_NAME" 2>/dev/null || true
  fi
  
  # Check for port conflicts
  check_redis_port_conflict
  
  # Start Redis container
  echo "==> Creating and starting Redis container '$REDIS_CONTAINER_NAME'"
  if ! docker run -d \
    --restart unless-stopped \
    -p "127.0.0.1:$REDIS_HOST_PORT:6379" \
    --name "$REDIS_CONTAINER_NAME" \
    -v "$REDIS_VOLUME_NAME":/data \
    "$REDIS_IMAGE_NAME" >/dev/null; then
    echo "ERROR: Failed to start Redis container. Port $REDIS_HOST_PORT might be in use by a non-Docker process."
    echo "Try: sudo lsof -i :$REDIS_HOST_PORT"
    exit 1
  fi
  
  # Start RedisInsight container
  echo "==> Creating and starting RedisInsight container '$REDIS_INSIGHT_CONTAINER_NAME'"
  if ! docker run -d \
    --restart unless-stopped \
    -p "127.0.0.1:$REDIS_INSIGHT_HOST_PORT:5540" \
    --name "$REDIS_INSIGHT_CONTAINER_NAME" \
    "$REDIS_INSIGHT_IMAGE_NAME" >/dev/null; then
    echo "ERROR: Failed to start RedisInsight container. Port $REDIS_INSIGHT_HOST_PORT might be in use by a non-Docker process."
    echo "Try: sudo lsof -i :$REDIS_INSIGHT_HOST_PORT"
    exit 1
  fi
  
  return 0
}

# Main logic - handle Redis or PostgreSQL
if [ "$use_redis" = true ]; then
  setup_redis
  show_ready_message=true
else
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
fi

# Show ready message only when container was started/created
if [ "$show_ready_message" = true ]; then
  # Wait a moment for container to be ready
  sleep 1
  echo
  
  if [ "$use_redis" = true ]; then
    echo "Your development Redis is ready!"
    echo "Connection details:"
    echo
    echo "  Redis: 127.0.0.1:$REDIS_HOST_PORT (no password)"
    echo "  RedisInsight: http://127.0.0.1:$REDIS_INSIGHT_HOST_PORT"
    echo
    echo "Add this to your environment variables:"
    echo
    echo "  export REDIS_URL='redis://127.0.0.1:$REDIS_HOST_PORT'"
  else
    echo "Your development database is ready!"
    echo "Add this to your environment variables:"
    echo
    echo "  export DATABASE_URL='postgresql://postgres@127.0.0.1:$HOST_PORT/postgres'"
  fi
  echo
fi


