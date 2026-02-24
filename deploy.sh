#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/mean"
ACTIVE_FILE="$APP_DIR/active_color"
UPSTREAM_FILE="/etc/nginx/conf.d/mean-upstream.conf"

compose() {
  if command -v docker-compose >/dev/null 2>&1; then
    sudo docker-compose "$@"
  else
    sudo docker compose "$@"
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
  if [[ -f "$ACTIVE_FILE" ]]; then
    cat "$ACTIVE_FILE"
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

compose -f "$APP_DIR/docker-compose.app.yml" -p "mean-${COLOR}" pull
FRONTEND_PORT="$FRONTEND_PORT" BACKEND_PORT="$BACKEND_PORT" \
  compose -f "$APP_DIR/docker-compose.app.yml" -p "mean-${COLOR}" up -d

update_nginx "$FRONTEND_PORT" "$BACKEND_PORT"

echo "$COLOR" > "$ACTIVE_FILE"

# Optional cleanup (uncomment if you want to reclaim space)
# docker image prune -f
