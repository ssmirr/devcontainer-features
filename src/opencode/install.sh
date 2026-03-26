#!/usr/bin/env bash
set -e

VERSION="${VERSION:-latest}"
PERMISSION="${PERMISSION:-allow}"
WEB="${WEB:-true}"
PORT="${PORT:-auto}"

REMOTE_USER_HOME="${_REMOTE_USER_HOME:-/home/${_REMOTE_USER:-vscode}}"

echo "Installing OpenCode (version: ${VERSION})..."

# Install OpenCode via official installer
# Unset VERSION when "latest" because the installer prepends 'v' making it "vlatest"
if [ "${VERSION}" = "latest" ]; then
    unset VERSION
    curl -fsSL https://opencode.ai/install | bash
else
    curl -fsSL https://opencode.ai/install | VERSION="${VERSION}" bash
fi

# The installer places the binary in ~/.local/bin/ of whoever runs it (root during build).
# Find it wherever it landed and make it globally available in /usr/local/bin/
if ! command -v opencode &>/dev/null; then
    FOUND=$(find / -name "opencode" -type f -executable 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
        cp "$FOUND" /usr/local/bin/opencode
        chmod +x /usr/local/bin/opencode
    fi
fi

opencode --version || echo "Warning: opencode installed but --version failed"

# Persist feature options for the start script
mkdir -p /usr/local/share/opencode
cat > /usr/local/share/opencode/env <<EOF
OPENCODE_WEB=${WEB}
OPENCODE_PORT=${PORT}
OPENCODE_PERMISSION=${PERMISSION}
EOF

# Symlink host config into the user's home so OpenCode picks it up
OPENCODE_CONFIG_DIR="${REMOTE_USER_HOME}/.config/opencode"
HOST_CONFIG_MOUNT="/usr/local/share/opencode/host-config"

mkdir -p "${HOST_CONFIG_MOUNT}" 2>/dev/null || true
mkdir -p "$(dirname "${OPENCODE_CONFIG_DIR}")"
if [ ! -e "${OPENCODE_CONFIG_DIR}" ]; then
    ln -sf "${HOST_CONFIG_MOUNT}" "${OPENCODE_CONFIG_DIR}"
fi

# Ensure correct ownership for the remote user
chown -R "${_REMOTE_USER:-vscode}:${_REMOTE_USER:-vscode}" "$(dirname "${OPENCODE_CONFIG_DIR}")" 2>/dev/null || true

# Write the postStartCommand script
# This runs after the container is fully up, so containerEnv and remoteEnv are available
cat > /usr/local/share/opencode-start.sh <<'STARTSCRIPT'
#!/usr/bin/env bash

# Load feature options saved at install time
if [ -f /usr/local/share/opencode/env ]; then
    set -a
    . /usr/local/share/opencode/env
    set +a
fi

if [ "${OPENCODE_WEB}" != "true" ]; then
    exit 0
fi

# Get workspace name from the current working directory (set by Dev Containers)
NAME=$(basename "$(pwd)")

# Resolve port: "auto" hashes the project name into a stable port
PORT="${OPENCODE_PORT}"
if [ "${PORT}" = "auto" ]; then
    HASH=$(echo -n "${NAME}" | cksum | awk '{print $1}')
    PORT=$(( (HASH % 50000) + 10000 ))
fi

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║  OpenCode Web UI                             ║"
printf "  ║  http://%s.opencode.local:%-5s              ║\n" "${NAME}" "${PORT}"
printf "  ║  http://localhost:%-5s                      ║\n" "${PORT}"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# Use CLI flags directly -- most reliable way to set port and hostname
nohup opencode web \
    --port "${PORT}" \
    --hostname "0.0.0.0" \
    > /tmp/opencode-web.log 2>&1 &

echo "OpenCode web UI started (PID: $!). Log: /tmp/opencode-web.log"
STARTSCRIPT
chmod +x /usr/local/share/opencode-start.sh

echo "OpenCode feature installed successfully."
