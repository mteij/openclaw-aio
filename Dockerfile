FROM node:22-bookworm

LABEL org.opencontainers.image.source="https://github.com/MTEIJ/openclaw-aio"
LABEL org.opencontainers.image.description="OpenClaw AIO: All-in-one OpenClaw docker image"

# --- 1. Install Bun (required for build scripts) ---
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable
WORKDIR /app

# --- 2. Install git (not in base image) ---
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# --- 3. Build Specific Version ---
ARG OPENCLAW_VERSION=main

# Clone and checkout specific version
RUN git clone --filter=blob:none --depth=1 https://github.com/openclaw/openclaw.git . && \
    git fetch --depth=1 origin ${OPENCLAW_VERSION} && \
    git checkout ${OPENCLAW_VERSION} && \
    rm -rf .git && \
    echo "Building OpenClaw Version: ${OPENCLAW_VERSION}"

RUN pnpm install --frozen-lockfile
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build

# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# Clean up build artifacts
RUN rm -rf node_modules/.cache .pnpm-store

# --- 3. Install Homebrew (as node user) ---
RUN mkdir -p /home/linuxbrew/.linuxbrew && chown -R node:node /home/linuxbrew
USER node
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

# Configure Brew Taps (enables web UI installs)
RUN brew tap steipete/tap && \
    brew tap openhue/cli && \
    brew tap yakitrak/yakitrak && \
    brew cleanup --prune=all && \
    rm -rf "$(brew --cache)"

# --- 4. Install Brew Packages (FULL variant only) ---
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

# --- 5. Install Playwright (with Chromium only) ---
USER root
ENV PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright
RUN mkdir -p /home/node/.cache/ms-playwright && chmod 777 /home/node/.cache/ms-playwright
# Use --with-deps to install ONLY Chromium and its specific dependencies (not all browsers)
RUN node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# --- 6. Final Config ---
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace /home/node/.npm-global && \
    chown -R node:node /home/node /app && \
    chmod -R 755 /home/node/.openclaw

USER node
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH="/home/node/.npm-global/bin:${PATH}"

# Install npm global packages (FULL variant only)
RUN if [ "$BREW_PACKAGES" = "FULL" ]; then \
      npm install -g clawhub @steipete/bird @steipete/oracle mcporter && \
      npm cache clean --force; \
    fi

WORKDIR /home/node
ENV NODE_ENV=production
ENV PATH="/app/node_modules/.bin:${PATH}"

ENTRYPOINT ["node", "/app/dist/index.js"]
CMD ["--help"]