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
RUN git clone --depth 1 --branch ${OPENCLAW_VERSION} https://github.com/openclaw/openclaw.git . && \
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

# --- 5. Install Playwright ---
USER root
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN mkdir -p /ms-playwright && chmod 777 /ms-playwright
RUN node /app/node_modules/playwright-core/cli.js install-deps
RUN node /app/node_modules/playwright-core/cli.js install chromium firefox webkit

# --- 6. Final Config ---
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace \
    && chown -R node:node /home/node /app \
    && chmod -R 755 /home/node/.openclaw

USER node
WORKDIR /home/node
ENV NODE_ENV=production
ENV PATH="/app/node_modules/.bin:${PATH}"

ENTRYPOINT ["node", "/app/dist/index.js"]
CMD ["--help"]