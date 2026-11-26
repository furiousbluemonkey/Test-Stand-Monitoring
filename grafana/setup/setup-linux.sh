#!/usr/bin/env bash
# Install Grafana and the Infinity plugin, then load this repo's data source and
# dashboard. Supports Debian/Ubuntu (apt) and Fedora/RHEL and derivatives (dnf/yum).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
until [[ -d "$ROOT/grafana/provisioning" ]]; do
  [[ "$ROOT" == / ]] && { echo 'Could not find grafana/provisioning above this script'; exit 1; }
  ROOT="$(dirname "$ROOT")"
done

# Where Grafana reads the dashboard JSON from.
# We copy the JSON here instead of pointing Grafana at the repo. Grafana runs as
# the "grafana" user, and on Fedora/RHEL home directories are mode 700, so it
# cannot read a repo under /home/you. SELinux (enforcing by default on Fedora/RHEL)
# can also block a service from reading user-home files even when the permissions
# look fine. The trade-off: after editing the dashboard in the repo, re-run this
# script to push the change.
DASH_DEST=/var/lib/grafana/dashboards

command -v systemctl >/dev/null || { echo 'systemd required'; exit 1; }

install_grafana_apt() {
  sudo apt-get update
  sudo apt-get install -y apt-transport-https wget gnupg ca-certificates
  sudo mkdir -p /etc/apt/keyrings
  sudo wget -qO /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key
  sudo chmod 644 /etc/apt/keyrings/grafana.asc
  echo 'deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main' | sudo tee /etc/apt/sources.list.d/grafana.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y grafana
}

install_grafana_rpm() {
  local pm="$1"   # dnf, or yum on older RHEL
  sudo rpm --import https://rpm.grafana.com/gpg.key
  sudo tee /etc/yum.repos.d/grafana.repo >/dev/null <<'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
EOF
  sudo "$pm" install -y grafana
}

# /usr/sbin may not be on a normal user's PATH on older Fedora/RHEL, so check it directly too.
if ! command -v grafana >/dev/null 2>&1 && [[ ! -x /usr/sbin/grafana ]]; then
  # Choose by package manager rather than distro name, so derivatives
  # (Rocky, Alma, Mint, ...) work without extra cases.
  if command -v apt-get >/dev/null; then
    install_grafana_apt
  elif command -v dnf >/dev/null; then
    install_grafana_rpm dnf
  elif command -v yum >/dev/null; then
    install_grafana_rpm yum
  else
    echo 'Unsupported system: need apt-get, dnf or yum'
    exit 1
  fi
fi

if [[ ! -f /var/lib/grafana/plugins/yesoreyeram-infinity-datasource/plugin.json ]]; then
  sudo grafana cli --pluginsDir /var/lib/grafana/plugins plugins install yesoreyeram-infinity-datasource || { echo 'Plugin installation failed; examine output'; exit 1; }
fi

# Data source and dashboard provider definitions (same paths on apt and rpm installs)
sudo install -d -m 755 /etc/grafana/provisioning/dashboards /etc/grafana/provisioning/datasources
sudo install -m 644 "$ROOT/grafana/provisioning/datasources/infinity.yaml" /etc/grafana/provisioning/datasources/logger-infinity.yaml

# Copy the dashboard JSON to the Grafana-owned folder (see DASH_DEST above)
shopt -s nullglob
dash_files=("$ROOT"/grafana/dashboards/*.json)
(( ${#dash_files[@]} )) || { echo "No dashboard JSON found in $ROOT/grafana/dashboards"; exit 1; }
sudo install -d -m 755 "$DASH_DEST"
sudo install -m 644 -t "$DASH_DEST" "${dash_files[@]}"

# Rewrite the provider's path: line to the fixed location. This assumes "options:"
# (with path: under it, indented 6 spaces) is the last block in dashboards.yaml.
sed '/^[[:space:]]*path:/d' "$ROOT/grafana/provisioning/dashboards/dashboards.yaml" | sudo tee /etc/grafana/provisioning/dashboards/logger-dashboard.yaml >/dev/null
printf '      path: %s\n' "$DASH_DEST" | sudo tee -a /etc/grafana/provisioning/dashboards/logger-dashboard.yaml >/dev/null

# On SELinux systems, give the copied files the labels Grafana is allowed to read.
# Harmless (and skipped) where SELinux isn't installed.
if command -v restorecon >/dev/null; then
  sudo restorecon -R /etc/grafana /var/lib/grafana || true
fi

sudo systemctl enable grafana-server
sudo systemctl restart grafana-server
printf 'Dashboard: http://localhost:3000/d/adkpsps\n'
printf 'API checks: curl -f http://127.0.0.1:8000/pressure.csv and curl -f http://127.0.0.1:8001/temperature.csv\n'