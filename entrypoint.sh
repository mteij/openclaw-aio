#!/bin/bash
set -e

# =============================================================================
# OpenClaw AIO Entrypoint Script
# Handles permissions, first-boot setup, and doctor fixes automatically
# =============================================================================

OPENCLAW_DIR="/home/node/.openclaw"
NPM_GLOBAL_DIR="/home/node/.npm-global"
FIRST_BOOT_MARKER="$OPENCLAW_DIR/.docker-initialized"

# =============================================================================
# PHASE 1: Root-only operations (permission fixes)
# =============================================================================
if [ "$(id -u)" = "0" ]; then
    # Create directories if they don't exist
    mkdir -p "$OPENCLAW_DIR" "$OPENCLAW_DIR/workspace" "$NPM_GLOBAL_DIR"
    
    # Fix ownership on EVERY run (handles volume mount issues, host changes, etc.)
    # Only chown if ownership is wrong (avoids unnecessary I/O on large directories)
    if [ "$(stat -c '%U' "$OPENCLAW_DIR" 2>/dev/null)" != "node" ]; then
        echo "🔧 Fixing ownership of $OPENCLAW_DIR..."
        chown -R node:node "$OPENCLAW_DIR"
    fi
    
    if [ "$(stat -c '%U' "$NPM_GLOBAL_DIR" 2>/dev/null)" != "node" ]; then
        chown -R node:node "$NPM_GLOBAL_DIR"
    fi
    
    # Ensure correct permissions
    chmod 700 "$OPENCLAW_DIR" 2>/dev/null || true
    
    # Re-execute this script as node user
    exec gosu node "$0" "$@"
fi

# =============================================================================
# PHASE 2: Node user operations (now running as node)
# =============================================================================

# Ensure PATH includes Homebrew and npm-global for all child processes
export PATH="/home/linuxbrew/.linuxbrew/bin:$NPM_GLOBAL_DIR/bin:${PATH}"
export NPM_CONFIG_PREFIX="$NPM_GLOBAL_DIR"

# Create workspace if missing
mkdir -p "$OPENCLAW_DIR/workspace" 2>/dev/null || true

# =============================================================================
# PHASE 3: First boot setup
# =============================================================================
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

# =============================================================================
# PHASE 4: Execute the actual command
# =============================================================================
exec node /app/dist/index.js "$@"
