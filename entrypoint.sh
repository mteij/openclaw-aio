#!/bin/bash
set -e

# =============================================================================
# OpenClaw AIO Entrypoint Script
# Handles permissions, first-boot setup, and doctor fixes automatically
# =============================================================================

# Ensure PATH includes Homebrew and npm-global for all child processes
export PATH="/home/linuxbrew/.linuxbrew/bin:/home/node/.npm-global/bin:${PATH}"
export NPM_CONFIG_PREFIX="/home/node/.npm-global"

OPENCLAW_DIR="/home/node/.openclaw"
FIRST_BOOT_MARKER="$OPENCLAW_DIR/.docker-initialized"

# 1. Fix ownership if running as root (handles volume mount permission issues)
#    Then re-exec as node user
if [ "$(id -u)" = "0" ]; then
    # Create and fix ownership of mounted directories
    mkdir -p "$OPENCLAW_DIR" "$OPENCLAW_DIR/workspace" /home/node/.npm-global
    chown -R node:node "$OPENCLAW_DIR" /home/node/.npm-global
    chmod 700 "$OPENCLAW_DIR"
    
    # Re-execute this script as node user
    exec gosu node "$0" "$@"
fi

# 2. Create required directories if missing (now running as node)
mkdir -p "$OPENCLAW_DIR/workspace" 2>/dev/null || true

# 3. Run doctor --fix on first boot only
if [ ! -f "$FIRST_BOOT_MARKER" ]; then
    echo "🦞 OpenClaw AIO - First boot detected"
    echo "   Running doctor --fix to ensure clean configuration..."
    echo ""
    
    # Run doctor --fix, don't fail if it errors (config might not exist yet)
    node /app/dist/index.js doctor --fix 2>/dev/null || true
    
    # Create marker so we don't run again
    touch "$FIRST_BOOT_MARKER" 2>/dev/null || true
    
    echo ""
    echo "✅ First boot setup complete!"
    echo ""
fi

# 4. Execute the actual command passed to the container
exec node /app/dist/index.js "$@"
