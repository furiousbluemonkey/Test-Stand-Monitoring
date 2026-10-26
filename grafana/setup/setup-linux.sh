#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ -f /etc/os-release ]] || { echo 'Linux with apt/systemd required'; exit 1; }
command -v apt-get >/dev/null || { echo 'This script supports Ubuntu/Debian only'; exit 1; }
command -v systemctl >/dev/null || { echo 'systemd required'; exit 1; }
if ! command -v grafana >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y apt-transport-https wget gnupg ca-certificates
  sudo mkdir -p /etc/apt/keyrings
  sudo wget -qO /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key
  sudo chmod 644 /etc/apt/keyrings/grafana.asc
  echo 'deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main' | sudo tee /etc/apt/sources.list.d/grafana.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y grafana
fi
if [[ ! -f /var/lib/grafana/plugins/yesoreyeram-infinity-datasource/plugin.json ]]; then
  sudo grafana cli --pluginsDir /var/lib/grafana/plugins plugins install yesoreyeram-infinity-datasource || { echo 'Plugin installation failed; examine output'; exit 1; }
fi
sudo install -d -m 755 /etc/grafana/provisioning/dashboards /etc/grafana/provisioning/datasources
sudo install -m 644 "$ROOT/grafana/provisioning/datasources/infinity.yaml" /etc/grafana/provisioning/datasources/logger-infinity.yaml
# Quote as a YAML single-quoted string. Duplicate apostrophes to escape them.
DASH_DIR="$ROOT/grafana/dashboards"
DASH_YAML="${DASH_DIR//\'/\'\'}"
sed '/^[[:space:]]*path:/d' "$ROOT/grafana/provisioning/dashboards/dashboards.yaml" | sudo tee /etc/grafana/provisioning/dashboards/logger-dashboard.yaml >/dev/null
printf "      path: '%s'\n" "$DASH_YAML" | sudo tee -a /etc/grafana/provisioning/dashboards/logger-dashboard.yaml >/dev/null
sudo systemctl enable --now grafana-server
sudo systemctl restart grafana-server
printf 'Dashboard: http://localhost:3000/d/adkpsps\n'
printf 'API checks: curl -f http://127.0.0.1:8000/pressure.csv and curl -f http://127.0.0.1:8001/temperature.csv\n'
