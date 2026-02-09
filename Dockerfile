# =============================================================================
# STAGE 1: Build
# =============================================================================
FROM node:22-bookworm AS builder

RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable

WORKDIR /app

# Install git for cloning
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

ARG OPENCLAW_VERSION=main

# Clone and build (handles both tags and commit SHAs)
RUN git clone --filter=blob:none https://github.com/openclaw/openclaw.git . && \
    git fetch --depth=1 origin ${OPENCLAW_VERSION} && \
    git checkout FETCH_HEAD && \
    rm -rf .git

RUN pnpm install --frozen-lockfile

RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# Prune dev dependencies - keep only production
RUN CI=true pnpm prune --prod

# =============================================================================
# STAGE 2: Runtime (much smaller!)
# =============================================================================
FROM node:22-bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/MTEIJ/openclaw-aio"
LABEL org.opencontainers.image.description="OpenClaw AIO: All-in-one OpenClaw docker image"

WORKDIR /app

# Copy only what we need from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/extensions ./extensions
COPY --from=builder /app/docs ./docs
COPY --from=builder /app/assets ./assets
COPY --from=builder /app/skills ./skills
COPY --from=builder /app/openclaw.mjs ./openclaw.mjs
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/README.md ./README.md
COPY --from=builder /app/LICENSE ./LICENSE
# Also copy dist/channels to valid plugin location if needed, 
# but dist/channels is inside dist so it's covered by above line.
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# Install runtime dependencies (minimal - Homebrew can use bottles)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates procps git gosu build-essential \
    && rm -rf /var/lib/apt/lists/*

# Setup directories and user
RUN mkdir -p /home/linuxbrew/.linuxbrew && chown -R node:node /home/linuxbrew

# Install Homebrew as node user
USER node
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

# Add taps for skill package installs
RUN brew tap steipete/tap && \
    brew tap openhue/cli && \
    brew tap yakitrak/yakitrak && \
    brew cleanup --prune=all && \
    rm -rf "$(brew --cache)"

# Install brew packages for FULL variant (requires build tools)
ARG BREW_PACKAGES="DEFAULT"
RUN if [ "$BREW_PACKAGES" = "FULL" ]; then \
      brew install gh ffmpeg ripgrep tmux openai-whisper himalaya uv \
        gemini-cli openhue/cli/openhue-cli \
        gifgrep gogcli goplaces obsidian-cli ordercli sag songsee wacli && \
      brew cleanup --prune=all && \
      rm -rf "$(brew --cache)"; \
    elif [ "$BREW_PACKAGES" != "DEFAULT" ] && [ -n "$BREW_PACKAGES" ]; then \
      brew install $BREW_PACKAGES && \
      brew cleanup --prune=all && \
      rm -rf "$(brew --cache)"; \
    fi

# Install Playwright (as root for system deps)
USER root
ENV PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright
RUN mkdir -p /home/node/.cache/ms-playwright && chmod 777 /home/node/.cache/ms-playwright
RUN node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Final setup - only chown the specific directories we created (not /home/node which includes Homebrew)
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace /home/node/.npm-global && \
    chown -R node:node /home/node/.openclaw /home/node/.npm-global && \
    chmod -R 755 /home/node/.openclaw

USER node
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH="/home/node/.npm-global/bin:${PATH}"

# Install npm globals for FULL variant
RUN if [ "$BREW_PACKAGES" = "FULL" ]; then \
      npm install -g clawhub @steipete/bird @steipete/oracle mcporter && \
      npm cache clean --force; \
    fi

WORKDIR /home/node
ENV NODE_ENV=production
ENV PATH="/app/node_modules/.bin:${PATH}"

# Copy and setup entrypoint script (as root)
USER root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Entrypoint runs as root to fix volume permissions, then drops to node
ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]