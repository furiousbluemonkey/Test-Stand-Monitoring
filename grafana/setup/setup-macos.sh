#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v brew >/dev/null || { echo 'Homebrew is required: https://brew.sh'; exit 1; }
brew list --versions grafana >/dev/null 2>&1 || brew install grafana
PREFIX="$(brew --prefix)"
GRAFANA_HOME="$PREFIX/opt/grafana/share/grafana"
GRAFANA_CFG="$PREFIX/etc/grafana/grafana.ini"
PLUGINS="$PREFIX/var/lib/grafana/plugins"
mkdir -p "$PLUGINS" "$PREFIX/etc/grafana/provisioning/dashboards" "$PREFIX/etc/grafana/provisioning/datasources"
if [[ ! -f "$PLUGINS/yesoreyeram-infinity-datasource/plugin.json" ]]; then
  "$PREFIX/opt/grafana/bin/grafana" cli --config "$GRAFANA_CFG" --homepath "$GRAFANA_HOME" --pluginsDir "$PLUGINS" plugins install yesoreyeram-infinity-datasource
fi
cp "$ROOT/grafana/provisioning/datasources/infinity.yaml" "$PREFIX/etc/grafana/provisioning/datasources/logger-infinity.yaml"
DASH_DIR="$ROOT/grafana/dashboards"
DASH_YAML="${DASH_DIR//\'/\'\'}"
sed '/^[[:space:]]*path:/d' "$ROOT/grafana/provisioning/dashboards/dashboards.yaml" > "$PREFIX/etc/grafana/provisioning/dashboards/logger-dashboard.yaml"
printf "      path: '%s'\n" "$DASH_YAML" >> "$PREFIX/etc/grafana/provisioning/dashboards/logger-dashboard.yaml"
# Homebrew's Grafana service reads its provisioning directory from the Homebrew config.
# Setting a process-level override in the plist is unnecessary if standard Homebrew paths are used.
brew services restart grafana
printf 'Dashboard: http://localhost:3000/d/adkpsps\n'
