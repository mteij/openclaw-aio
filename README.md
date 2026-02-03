# 🦞 OpenClaw AIO

Pre-built [OpenClaw](https://github.com/openclaw/openclaw) Docker image with Homebrew + Playwright included.

## Usage

```bash
git clone https://github.com/MTEIJ/openclaw-aio.git && cd openclaw-aio
cp .env.example .env
docker compose run --rm openclaw-cli onboard
docker compose up -d openclaw-gateway
```

## Tags

| Tag              | Description                             |
| ---------------- | --------------------------------------- |
| `latest`         | Stable (Homebrew ready, no packages)    |
| `latest-full`    | Stable (all skill tools pre-installed)  |
| `v2026.x.x`      | Version (Homebrew ready, no packages)   |
| `v2026.x.x-full` | Version (all skill tools pre-installed) |
| `dev-latest`     | Dev (Homebrew ready, no packages)       |
| `dev-<sha>`      | Commit (Homebrew ready, no packages)    |

**Default:** Homebrew installed and ready. Install packages as needed with `brew install <package>`.

**Full:** gh, ffmpeg, ripgrep, tmux, whisper, himalaya, uv, gemini-cli, openhue-cli, gifgrep, gog, goplaces, camsnap, obsidian-cli, ordercli, sag, songsee, summarize, wacli
