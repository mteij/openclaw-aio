FROM node:22-bookworm

LABEL org.opencontainers.image.source="https://github.com/MTEIJ/openclaw-aio"
LABEL org.opencontainers.image.description="OpenClaw AIO: All-in-one OpenClaw docker image"

# --- 1. Install System Dependencies ---
RUN apt-get update && apt-get install -y \
    git curl jq unzip ca-certificates \
    build-essential procps python3 sudo \
    && rm -rf /var/lib/apt/lists/*

# --- 2. Install Bun ---
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable
WORKDIR /app

# --- 3. Build Specific Version (The Magic Part) ---
# This argument will be passed by GitHub Actions
ARG OPENCLAW_VERSION=main

# Clone the specific release tag (e.g., v2026.2.1)
# Use --filter=blob:none to support both tags and commit SHAs efficiently
RUN git clone --filter=blob:none https://github.com/openclaw/openclaw.git . && \
    git checkout ${OPENCLAW_VERSION} && \
    echo "Building OpenClaw Version: ${OPENCLAW_VERSION}"

RUN pnpm install --frozen-lockfile
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build

# Force bash for UI build
RUN npm_config_script_shell=bash pnpm ui:install
RUN npm_config_script_shell=bash pnpm ui:build

# Clean up
RUN rm -rf .git node_modules/.cache

# --- 4. Install Homebrew ---
RUN mkdir -p /home/linuxbrew/.linuxbrew && chown -R node:node /home/linuxbrew
USER node
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"
RUN echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/node/.bashrc

# --- 4b. Configure Brew Taps (for all variants, enables web UI installs) ---
RUN brew tap steipete/tap && \
    brew tap openhue/cli && \
    brew tap yakitrak/yakitrak

# --- 4c. Install Brew Packages ---
# BREW_PACKAGES: "DEFAULT" (none), "FULL" (all skill tools), or custom list
ARG BREW_PACKAGES="DEFAULT"
RUN if [ "$BREW_PACKAGES" = "FULL" ]; then \
      brew install gh ffmpeg ripgrep tmux openai-whisper himalaya uv \
        gemini-cli openhue/cli/openhue-cli \
        gifgrep gogcli goplaces obsidian-cli ordercli sag songsee wacli; \
    elif [ "$BREW_PACKAGES" != "DEFAULT" ] && [ -n "$BREW_PACKAGES" ]; then \
      brew install $BREW_PACKAGES; \
    fi

# --- 5. Install Playwright ---
USER root
ENV PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright
RUN mkdir -p /home/node/.cache/ms-playwright && chmod 777 /home/node/.cache/ms-playwright
RUN node /app/node_modules/playwright-core/cli.js install-deps
RUN node /app/node_modules/playwright-core/cli.js install chromium

# --- 6. Final Config ---
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace /home/node/.npm-global \
    && chown -R node:node /home/node /app \
    && chmod -R 755 /home/node/.openclaw

# --- 6b. Configure npm global for node user ---
USER node
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH="/home/node/.npm-global/bin:${PATH}"

# --- 6c. Install npm global packages (for FULL variant) ---
RUN if [ "$BREW_PACKAGES" = "FULL" ]; then \
      npm install -g clawhub @steipete/bird @steipete/oracle mcporter; \
    fi
WORKDIR /home/node
ENV NODE_ENV=production
ENV PATH="/app/node_modules/.bin:${PATH}"

ENTRYPOINT ["node", "/app/dist/index.js"]
CMD ["--help"]