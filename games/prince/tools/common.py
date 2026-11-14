"""Where the generators find the OpenRouter key.

The key lives in `.env` at the repo root. In a git worktree there is no
`.env` (it's ignored), so this also looks beside the main checkout. The key
is only ever read into memory, never printed.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent.parent


def env_paths() -> list[Path]:
    paths = [REPO / ".env"]
    try:
        common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=REPO,
                                capture_output=True, text=True, check=True).stdout.strip()
        paths.append(Path(common).parent / ".env")
    except (OSError, subprocess.CalledProcessError):
        pass
    return paths


def load_env() -> dict[str, str]:
    values: dict[str, str] = {}
    for path in env_paths():
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, value = line.partition("=")
                values[key.strip()] = value.strip().strip('"').strip("'")
        break
    return values


def api() -> tuple[str, str]:
    """(base url, key), or exits if the key is missing."""
    env = load_env()
    key = env.get("OPENROUTER_API_KEY", "")
    if not key:
        raise SystemExit("OPENROUTER_API_KEY is missing from .env")
    return env.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/"), key
