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

# 1. Fix directory permissions (the #1 issue users hit)
if [ -d "$OPENCLAW_DIR" ]; then
    chmod 700 "$OPENCLAW_DIR" 2>/dev/null || true
fi

# 2. Create required directories if missing
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
