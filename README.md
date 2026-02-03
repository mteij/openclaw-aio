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

| Tag              | Description         |
| ---------------- | ------------------- |
| `latest`         | Stable (default)    |
| `latest-full`    | Stable (all tools)  |
| `v2026.x.x`      | Version (default)   |
| `v2026.x.x-full` | Version (all tools) |
| `dev-latest`     | Dev (default)       |
| `dev-<sha>`      | Commit (default)    |

**Default:** gh, ffmpeg, ripgrep, tmux, whisper, openhue, himalaya

**Full:** Default + gemini, gifgrep, gog, goplaces, camsnap, obsidian-cli, ordercli, sag, songsee, summarize, wacli, uv
