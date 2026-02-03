# 🦞 OpenClaw AIO

Pre-built [OpenClaw](https://github.com/openclaw/openclaw) Docker image with Homebrew + Playwright included.

**Skills-ready:** gh, ffmpeg, ripgrep, tmux, whisper, openhue, himalaya pre-installed.

## Usage

```bash
git clone https://github.com/MTEIJ/openclaw-aio.git && cd openclaw-aio
cp .env.example .env
docker compose run --rm openclaw-cli onboard
docker compose up -d openclaw-gateway
```

## Tags

| Tag          | Description        |
| ------------ | ------------------ |
| `latest`     | Stable release     |
| `v2026.x.x`  | Specific version   |
| `dev-latest` | Latest main branch |
| `dev-<sha>`  | Specific commit    |
