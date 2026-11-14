#!/usr/bin/env bash
# Prince of Versions' checks, as CI runs them: every room's solution and
# every probe through the in-game Git (tests/replay.gd), the same commands
# against the real git (tests/verify_git.ts), then the bot through every
# room. Uses $GODOT if set, else fetches Godot the way the export scripts do.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PRINCE="${ROOT}/games/prince"
if [[ -z "${GODOT:-}" ]]; then
  source "${ROOT}/scripts/godot_setup.sh"
fi

"$GODOT" --headless --path "$PRINCE" --import
"$GODOT" --headless --path "$PRINCE" --script res://tests/replay.gd | tee /tmp/prince_replay.log
grep -q "REPLAY result=ok" /tmp/prince_replay.log
bun "${PRINCE}/tests/verify_git.ts" --require
"$GODOT" --headless --path "$PRINCE" res://tests/bot.tscn | tee /tmp/prince_bot.log
grep -q "BOT result=ok" /tmp/prince_bot.log
