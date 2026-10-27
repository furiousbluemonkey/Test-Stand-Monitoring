#!/usr/bin/env bash
set -euo pipefail

# Run from anywhere: bash grafana/setup/setup-macos.sh
REPO="$(cd "$(dirname "$0")/../.." && pwd -P)"
BASE="$HOME/Applications/grafana"
VERSION="13.2.4"
BUILD="38252365904"

case "$(uname -m)" in
  x86_64) ARCH=amd64 ;;
  arm64)  ARCH=arm64 ;;
  *) echo "Unsupported Mac architecture" >&2; exit 1 ;;
esac

ARCHIVE="grafana_${VERSION}_${BUILD}_darwin_${ARCH}.tar.gz"
URL="https://dl.grafana.com/grafana/release/${VERSION}/${ARCHIVE}"
mkdir -p "$BASE"
cd "$BASE"

# Download and extract Grafana.
curl -fL "$URL" -o "$ARCHIVE"
tar -xzf "$ARCHIVE"
rm "$ARCHIVE"

# Locate the extracted Grafana directory.
GRAFANA_HOME="$(find "$BASE" -maxdepth 3 -type f -path '*/bin/grafana' -print -quit)"
GRAFANA_HOME="${GRAFANA_HOME%/bin/grafana}"
[ -n "$GRAFANA_HOME" ] || { echo "Grafana binary not found" >&2; exit 1; }

mkdir -p "$GRAFANA_HOME/data/plugins" \
  "$GRAFANA_HOME/conf/provisioning/datasources" \
  "$GRAFANA_HOME/conf/provisioning/dashboards"

# Install Infinity.
"$GRAFANA_HOME/bin/grafana" cli --homepath "$GRAFANA_HOME" \
  --pluginsDir "$GRAFANA_HOME/data/plugins" \
  plugins install yesoreyeram-infinity-datasource

# Configure the data source.
cp "$REPO/grafana/provisioning/datasources/infinity.yaml" \
  "$GRAFANA_HOME/conf/provisioning/datasources/logger-infinity.yaml"

# Configure dashboard provisioning.
sed "s|/absolute/path/to/repo/grafana/dashboards|$REPO/grafana/dashboards|" \
  "$REPO/grafana/provisioning/dashboards/dashboards.yaml" \
  > "$GRAFANA_HOME/conf/provisioning/dashboards/logger-dashboard.yaml"

# Create the grafana-start command.
mkdir -p "$HOME/bin"
printf -v GRAFANA_DIR '%q' "$GRAFANA_HOME"
cat > "$HOME/bin/grafana-start" <<EOF
#!/usr/bin/env bash
cd $GRAFANA_DIR || exit 1
export GF_PATHS_DATA="\$PWD/data"
export GF_PATHS_PLUGINS="\$PWD/data/plugins"
export GF_PATHS_PROVISIONING="\$PWD/conf/provisioning"
exec ./bin/grafana server
EOF
chmod +x "$HOME/bin/grafana-start"

# Add ~/bin to PATH for new Terminal sessions.
touch "$HOME/.zshrc"
PATH_LINE='export PATH="$HOME/bin:$PATH"'
grep -Fqx "$PATH_LINE" "$HOME/.zshrc" || printf '\n%s\n' "$PATH_LINE" >> "$HOME/.zshrc"

echo "Installation complete. Open a new Terminal and run: grafana-start"
echo "Dashboard: http://localhost:3000/d/adkpsps"
