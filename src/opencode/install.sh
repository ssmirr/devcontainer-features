#!/usr/bin/env bash
set -e

VERSION="${VERSION:-latest}"
PERMISSION="${PERMISSION:-allow}"

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
# Explicitly copy it to /usr/local/bin/ so it's available to all users.
if ! command -v opencode &>/dev/null; then
    for p in /root/.local/bin/opencode "${HOME}/.local/bin/opencode"; do
        if [ -f "$p" ]; then
            cp "$p" /usr/local/bin/opencode
            chmod +x /usr/local/bin/opencode
            break
        fi
    done
fi

# Last resort: search the entire filesystem
if ! command -v opencode &>/dev/null; then
    FOUND=$(find / -name "opencode" -type f -executable 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
        cp "$FOUND" /usr/local/bin/opencode
        chmod +x /usr/local/bin/opencode
    fi
fi

opencode --version || { echo "ERROR: opencode binary not found after install"; exit 1; }

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

# Create start/stop convenience commands
cat > /usr/local/bin/opencode-web <<'SCRIPT'
#!/usr/bin/env bash
NAME=$(basename "$(pwd)")
HASH=$(echo -n "${NAME}" | cksum | awk '{print $1}')
PORT=$(( (HASH % 50000) + 10000 ))

# Load permission from feature install
PERM="allow"
if [ -f /usr/local/share/opencode/env ]; then
    . /usr/local/share/opencode/env
    PERM="${OPENCODE_PERMISSION:-allow}"
fi

export OPENCODE_CONFIG_CONTENT="{\"permission\":\"${PERM}\"}"

echo ""
echo "  OpenCode Web UI"
echo "  http://${NAME}.opencode.local:${PORT}"
echo "  http://localhost:${PORT}"
echo ""
exec opencode web --port "${PORT}" --hostname 0.0.0.0
SCRIPT
chmod +x /usr/local/bin/opencode-web

cat > /usr/local/bin/opencode-stop <<'SCRIPT'
#!/usr/bin/env bash
pkill -f "opencode web" 2>/dev/null && echo "OpenCode stopped." || echo "OpenCode is not running."
SCRIPT
chmod +x /usr/local/bin/opencode-stop

# Save permission for the start script
mkdir -p /usr/local/share/opencode
echo "OPENCODE_PERMISSION=${PERMISSION}" > /usr/local/share/opencode/env

echo "OpenCode feature installed successfully."
echo "Run 'opencode-web' to start the web UI, Ctrl+C or 'opencode-stop' to stop it."
