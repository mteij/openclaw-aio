# 🦞 OpenClaw AIO (All-In-One)

Builds from the [official source](https://github.com/openclaw/openclaw), pre-installed with **Homebrew**, **Playwright (Browsers included)**, and system tools (`git`, `curl`, `jq`).

###  Usage (Docker Compose)
Replace `yourusername` with your GitHub handle.

```yaml
services:
  openclaw-gateway:
    image: ghcr.io/yourusername/openclaw-aio:latest
    container_name: openclaw-gateway
    restart: unless-stopped
    volumes:
      - openclaw_home:/home/node
      - ./config:/home/node/.openclaw
      - ./workspace:/home/node/.openclaw/workspace
    environment:
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
      - OPENCLAW_SKIP_SERVICE_CHECK=true
    command: ["gateway"]

  openclaw-cli:
    image: ghcr.io/yourusername/openclaw-aio:latest
    container_name: openclaw-cli
    stdin_open: true
    tty: true
    volumes:
      - openclaw_home:/home/node
      - ./config:/home/node/.openclaw
      - ./workspace:/home/node/.openclaw/workspace
    environment:
      - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
    entrypoint: ["node", "/app/dist/index.js"]
    profiles: ["cli"]

volumes:
  openclaw_home: