# Dunder Quest

Pixel-art games that teach programming, playable at [dunderquest.com](https://dunderquest.com).

| Folder | What it is |
| --- | --- |
| `games/dunder-quest/` | Dunder Quest, the Python platformer (Godot 4.7). Plays at `/play/`. |
| `games/flatmates/` | Flatmates.js, the JavaScript game (Godot 4.7). Plays at `/flatmates/play/`. See its [README](games/flatmates/README.md). |
| `games/curb/` | Curb Your Oxidation, the Rust game (Godot 4.7). Plays at `/curb/play/`. See its [README](games/curb/README.md). |
| `site/` | `build.py` writes the static site: home, lessons, guide, brand and the Flatmates.js page. |
| `scripts/` | `export_web.sh` builds the site and the three web games into `build/site`; `export_desktop.sh` builds Dunder Quest's desktop downloads. |
| `deploy/` | Cloudflare deploy of `build/site`. |
| `stats/` | The play-stats dashboard and its D1 database. See its [README](stats/README.md). |

Each game is its own Godot project: open `games/<game>/project.godot`. Their art, music and trailer tools live in each game's `tools/` and run from that game's folder (`python tools/...`). Flatmates.js and Curb Your Oxidation reuse Dunder Quest's generators. The OpenRouter key for those tools goes in `.env` at the repo root (copy `.env.example`).

CI (`.github/workflows/deploy.yml`) builds everything on every push and pull request, deploys PRs and `dev` to dev.dunderquest.com and `main` to production.
