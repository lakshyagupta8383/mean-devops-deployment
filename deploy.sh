#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/mean"
ACTIVE_FILE="$APP_DIR/active_color"
UPSTREAM_FILE="/etc/nginx/snippets/mean-upstream.conf"
COMPOSE_V1=0

compose() {
  local sudo_cmd=()
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    sudo_cmd=(sudo -E)
  fi
  # Prefer Compose v2; docker-compose v1 can fail with newer Docker metadata
  if "${sudo_cmd[@]}" docker compose version >/dev/null 2>&1; then
    COMPOSE_V1=0
    "${sudo_cmd[@]}" docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_V1=1
    "${sudo_cmd[@]}" docker-compose "$@"
  else
    echo "ERROR: Docker Compose is not available (need docker compose plugin or docker-compose)." >&2
    exit 1
  fi
}

ensure_network() {
  if ! sudo docker network inspect mean-net >/dev/null 2>&1; then
    sudo docker network create mean-net
  fi
}

ensure_mongo() {
  compose -f "$APP_DIR/docker-compose.mongo.yml" up -d
}

current_color() {
  if sudo test -f "$ACTIVE_FILE"; then
    sudo cat "$ACTIVE_FILE"
  else
    echo "blue"
  fi
}

next_color() {
  if [[ "$(current_color)" == "blue" ]]; then
    echo "green"
  else
    echo "blue"
  fi
}

ports_for() {
  if [[ "$1" == "blue" ]]; then
    echo "4200 8080"
  else
    echo "4201 8081"
  fi
}

update_nginx() {
  local fport="$1"
  local bport="$2"
  sudo tee "$UPSTREAM_FILE" >/dev/null <<EOF
set \$mean_frontend http://127.0.0.1:${fport};
set \$mean_backend http://127.0.0.1:${bport};
EOF
  sudo nginx -t
  sudo systemctl reload nginx
}

cd "$APP_DIR"

ensure_network
ensure_mongo

COLOR="$(next_color)"
read -r FRONTEND_PORT BACKEND_PORT < <(ports_for "$COLOR")

echo "Deploying color: $COLOR (frontend=$FRONTEND_PORT backend=$BACKEND_PORT)"

compose -f "$APP_DIR/docker-compose.app.${COLOR}.yml" -p "mean-${COLOR}" pull
# docker-compose v1 can fail while recreating existing containers
# with newer Docker/image metadata; clean the inactive color first.
if [[ "$COMPOSE_V1" -eq 1 ]]; then
  compose -f "$APP_DIR/docker-compose.app.${COLOR}.yml" -p "mean-${COLOR}" down --remove-orphans || true
fi
compose -f "$APP_DIR/docker-compose.app.${COLOR}.yml" -p "mean-${COLOR}" up -d

update_nginx "$FRONTEND_PORT" "$BACKEND_PORT"

echo "$COLOR" | sudo tee "$ACTIVE_FILE" >/dev/null

# Optional cleanup (uncomment if you want to reclaim space)
# docker image prune -f
