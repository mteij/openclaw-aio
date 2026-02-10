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
    
    # =========================================================================
    # APT AUTO-PERSISTENCE RESTORE
    # =========================================================================
    APT_PACKAGES=""
    
    # 1. From Environment Variable
    if [ -n "$EXTRA_APT_PACKAGES" ]; then
        APT_PACKAGES="$APT_PACKAGES $EXTRA_APT_PACKAGES"
    fi
    
    # 2. From Persistence File
    if [ -f "$OPENCLAW_DIR/apt-packages.txt" ]; then
        # Read file, ignore comments/empty lines, replace newlines with spaces
        FILE_PACKAGES=$(grep -vE '^\s*#|^\s*$' "$OPENCLAW_DIR/apt-packages.txt" | tr '\n' ' ')
        APT_PACKAGES="$APT_PACKAGES $FILE_PACKAGES"
    fi
    
    # 3. Install if we have packages
    if [ -n "$APT_PACKAGES" ]; then
        echo "📦 Restoring persistent apt packages: $APT_PACKAGES"
        if [ -x "/usr/bin/apt-get" ]; then
            apt-get update -qq >/dev/null
            # Use DEBIAN_FRONTEND=noninteractive to avoid prompts
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $APT_PACKAGES
            # Clean up to save space (though less critical in runtime)
            rm -rf /var/lib/apt/lists/*
        else 
            echo "⚠️  Warning: apt-get not found, skipping package restoration."
        fi
    fi

    # Re-execute this script as node user
    exec gosu node "$0" "$@"
fi

# =============================================================================
# PHASE 2: Node user operations (now running as node)
# =============================================================================

# Ensure PATH includes Wrappers, Homebrew and npm-global
export PATH="/app/scripts/wrappers:/home/linuxbrew/.linuxbrew/bin:$NPM_GLOBAL_DIR/bin:${PATH}"
export NPM_CONFIG_PREFIX="$NPM_GLOBAL_DIR"

# Create workspace if missing
mkdir -p "$OPENCLAW_DIR/workspace" 2>/dev/null || true

# =============================================================================
# AUTO-PERSISTENCE RESTORE (User Level)
# =============================================================================

# Brew/NPM restoration is now handled by scripts/bootstrap.js in Phase 4

# Ensure Gateway Token is configured (for CLI/Playwright access)
if [ -n "$OPENCLAW_GATEWAY_TOKEN" ]; then
    node /app/scripts/configure-token.js
fi

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
# Check if first argument is an absolute path or specific allowed command (bash, sh, openclaw)
# We avoid `command -v` because it shadows CLI commands like 'install' which are also system commands.
if [[ "$1" == /* ]] || [[ "$1" == "bash" ]] || [[ "$1" == "sh" ]] || [[ "$1" == "openclaw" ]] || [[ "$1" == "node" ]] || [[ "$1" == "npm" ]] || [[ "$1" == "npx" ]]; then
    # Run integrated bootstrap (Checks + Restore)
    node /app/scripts/bootstrap.js || true
    exec "$@"
else
    # Otherwise assume it's an OpenClaw CLI command/flag
    exec node /app/dist/index.js "$@"
fi
