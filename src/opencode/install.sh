#!/usr/bin/env bash
set -e

VERSION="${VERSION:-latest}"
PERMISSION="${PERMISSION:-allow}"
WEB="${WEB:-true}"
PORT="${PORT:-auto}"

REMOTE_USER_HOME="${_REMOTE_USER_HOME:-/home/${_REMOTE_USER:-vscode}}"

echo "Installing OpenCode (version: ${VERSION})..."

# Install OpenCode via official installer
# Only pass VERSION to the installer if a specific version was requested.
# The installer prepends 'v' to VERSION, so "latest" would become "vlatest".
if [ "${VERSION}" = "latest" ]; then
    unset VERSION
    curl -fsSL https://opencode.ai/install | bash
else
    curl -fsSL https://opencode.ai/install | VERSION="${VERSION}" bash
fi

# Ensure opencode is in PATH
if ! command -v opencode &>/dev/null; then
    for p in /usr/local/bin/opencode /root/.local/bin/opencode "${REMOTE_USER_HOME}/.local/bin/opencode"; do
        if [ -f "$p" ]; then
            ln -sf "$p" /usr/local/bin/opencode
            break
        fi
    done
fi

opencode --version || echo "Warning: opencode installed but --version failed"

# Persist feature options for the entrypoint
mkdir -p /usr/local/share/opencode
cat > /usr/local/share/opencode/env <<EOF
OPENCODE_WEB=${WEB}
OPENCODE_PORT=${PORT}
OPENCODE_PERMISSION=${PERMISSION}
EOF

# Symlink host config into the user's home so OpenCode picks it up.
# The host config is bind-mounted to /usr/local/share/opencode/host-config by the feature.
# If the host dir doesn't exist, the mount may fail or be empty -- handle gracefully.
OPENCODE_CONFIG_DIR="${REMOTE_USER_HOME}/.config/opencode"
HOST_CONFIG_MOUNT="/usr/local/share/opencode/host-config"

mkdir -p "${HOST_CONFIG_MOUNT}" 2>/dev/null || true
mkdir -p "$(dirname "${OPENCODE_CONFIG_DIR}")"
if [ ! -e "${OPENCODE_CONFIG_DIR}" ]; then
    ln -sf "${HOST_CONFIG_MOUNT}" "${OPENCODE_CONFIG_DIR}"
fi

# Ensure correct ownership for the remote user
chown -R "${_REMOTE_USER:-vscode}:${_REMOTE_USER:-vscode}" "$(dirname "${OPENCODE_CONFIG_DIR}")" 2>/dev/null || true

# Write entrypoint script
cat > /usr/local/share/opencode-entrypoint.sh <<'ENTRY'
#!/usr/bin/env bash

# Load feature options saved at install time
if [ -f /usr/local/share/opencode/env ]; then
    set -a
    . /usr/local/share/opencode/env
    set +a
fi

if [ "${OPENCODE_WEB}" = "true" ]; then
    # Resolve workspace name from the workspace folder path
    WORKSPACE_FOLDER="${CONTAINER_WORKSPACE_FOLDER:-/workspace}"
    NAME=$(basename "${WORKSPACE_FOLDER}")

    # Resolve port: "auto" hashes the project name into a stable port
    PORT="${OPENCODE_PORT}"
    if [ "${PORT}" = "auto" ]; then
        HASH=$(echo -n "${NAME}" | cksum | awk '{print $1}')
        PORT=$(( (HASH % 50000) + 10000 ))
    fi

    export OPENCODE_CONFIG_CONTENT="{\"permission\":\"${OPENCODE_PERMISSION:-allow}\",\"server\":{\"port\":${PORT},\"hostname\":\"0.0.0.0\"}}"

    echo ""
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║  OpenCode Web UI                             ║"
    printf "  ║  http://%s.opencode.local:%-5s              ║\n" "${NAME}" "${PORT}"
    printf "  ║  http://localhost:%-5s                      ║\n" "${PORT}"
    echo "  ╚══════════════════════════════════════════════╝"
    echo ""

    nohup opencode web > /tmp/opencode-web.log 2>&1 &
fi

exec "$@"
ENTRY
chmod +x /usr/local/share/opencode-entrypoint.sh

echo "OpenCode feature installed successfully."
