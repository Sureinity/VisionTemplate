#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/var/www/VisionTemplate"
NGINX_UPSTREAM_CONF="/etc/nginx/conf.d/vision_upstream.conf"
IMAGE="visiontemplate"
HEALTH_PATH="/api/ping"
NETWORK="vision_network"
ENV_FILE="$APP_DIR/.env"
CONTAINER_PORT="3000"
GREEN_CONTAINER="vision_app_green"
BLUE_CONTAINER="vision_app_blue"
GREEN_PORT="3000"
BLUE_PORT="3001"
HEALTH_ATTEMPTS="12"
HEALTH_SLEEP_SECONDS="5"

container_running() {
  local name="$1"
  [ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || true)" = "true" ]
}

remove_container_if_exists() {
  local name="$1"
  if docker inspect "$name" >/dev/null 2>&1; then
    docker rm -f "$name" >/dev/null
  fi
}

write_upstream() {
  local port="$1"
  cat > "$NGINX_UPSTREAM_CONF" <<UPSTREAM
upstream vision_backend { server 127.0.0.1:$port; }
UPSTREAM
}

restore_previous_upstream() {
  local previous_content="$1"
  local had_previous="$2"

  if [ "$had_previous" = "true" ]; then
    printf '%s' "$previous_content" > "$NGINX_UPSTREAM_CONF"
  else
    rm -f "$NGINX_UPSTREAM_CONF"
  fi
}

cd "$APP_DIR"
git pull

ACTIVE_COLOR=""
ACTIVE_CONTAINER=""
NEW_COLOR="green"
NEW_CONTAINER="$GREEN_CONTAINER"
STANDBY_PORT="$GREEN_PORT"

if container_running "$GREEN_CONTAINER"; then
  ACTIVE_COLOR="green"
  ACTIVE_CONTAINER="$GREEN_CONTAINER"
  NEW_COLOR="blue"
  NEW_CONTAINER="$BLUE_CONTAINER"
  STANDBY_PORT="$BLUE_PORT"
elif container_running "$BLUE_CONTAINER"; then
  ACTIVE_COLOR="blue"
  ACTIVE_CONTAINER="$BLUE_CONTAINER"
  NEW_COLOR="green"
  NEW_CONTAINER="$GREEN_CONTAINER"
  STANDBY_PORT="$GREEN_PORT"
fi

if [ -n "$ACTIVE_COLOR" ]; then
  echo "Active container: $ACTIVE_CONTAINER ($ACTIVE_COLOR). Deploying $NEW_COLOR on port $STANDBY_PORT."
else
  echo "No active app container detected. Starting initial $NEW_COLOR deployment on port $STANDBY_PORT."
fi

if ! docker build -t "$IMAGE:$NEW_COLOR" .; then
  echo "Build failed — active container and Nginx upstream stay unchanged. Rollback complete."
  exit 1
fi

remove_container_if_exists "$NEW_CONTAINER"

docker run -d \
  --name "$NEW_CONTAINER" \
  --network "$NETWORK" \
  --env-file "$ENV_FILE" \
  -p "127.0.0.1:$STANDBY_PORT:$CONTAINER_PORT" \
  "$IMAGE:$NEW_COLOR" >/dev/null

HEALTH_URL="http://127.0.0.1:$STANDBY_PORT$HEALTH_PATH"
HEALTH_OK="false"

for attempt in $(seq 1 "$HEALTH_ATTEMPTS"); do
  http_code="$(curl -s -o /dev/null -w '%{http_code}' "$HEALTH_URL" || true)"
  if [ "$http_code" = "200" ]; then
    HEALTH_OK="true"
    echo "Health check passed for $NEW_CONTAINER at $HEALTH_URL."
    break
  fi
  echo "Health check attempt $attempt/$HEALTH_ATTEMPTS returned '$http_code'; retrying in ${HEALTH_SLEEP_SECONDS}s."
  sleep "$HEALTH_SLEEP_SECONDS"
done

if [ "$HEALTH_OK" != "true" ]; then
  remove_container_if_exists "$NEW_CONTAINER"
  echo "Health check failed — removed failed standby container $NEW_CONTAINER. Active container and Nginx upstream stay unchanged. Rollback complete."
  exit 1
fi

HAD_PREVIOUS_UPSTREAM="false"
PREVIOUS_UPSTREAM_CONTENT=""
if [ -f "$NGINX_UPSTREAM_CONF" ]; then
  HAD_PREVIOUS_UPSTREAM="true"
  PREVIOUS_UPSTREAM_CONTENT="$(cat "$NGINX_UPSTREAM_CONF")"
fi

write_upstream "$STANDBY_PORT"

if ! nginx -t; then
  restore_previous_upstream "$PREVIOUS_UPSTREAM_CONTENT" "$HAD_PREVIOUS_UPSTREAM"
  remove_container_if_exists "$NEW_CONTAINER"
  echo "Nginx config test failed — restored previous upstream and removed new standby container. Active container and Nginx upstream stay unchanged. Rollback complete."
  exit 1
fi

if ! nginx -s reload; then
  restore_previous_upstream "$PREVIOUS_UPSTREAM_CONTENT" "$HAD_PREVIOUS_UPSTREAM"
  remove_container_if_exists "$NEW_CONTAINER"
  echo "Nginx reload failed — restored previous upstream and removed new standby container. Active container and Nginx upstream stay unchanged. Rollback complete."
  exit 1
fi

if [ -n "$ACTIVE_CONTAINER" ]; then
  remove_container_if_exists "$ACTIVE_CONTAINER"
  echo "Stopped and removed old container $ACTIVE_CONTAINER."
fi

echo "Deployment complete: $NEW_CONTAINER is active on host port $STANDBY_PORT."
