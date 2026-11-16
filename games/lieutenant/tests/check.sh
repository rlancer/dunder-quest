#!/usr/bin/env bash
# Just One More JOIN's checks, as CI runs them: every question's solution
# and every query its page can spell through the in-game SQL engine
# (tests/replay.gd), the same SQL through the real SQLite (tests/verify_sql.ts),
# then the bot through the prologue and every case. Uses $GODOT if set, else
# fetches Godot the way the export scripts do.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GAME="${ROOT}/games/lieutenant"
if [[ -z "${GODOT:-}" ]]; then
  source "${ROOT}/scripts/godot_setup.sh"
fi

"$GODOT" --headless --path "$GAME" --import
"$GODOT" --headless --path "$GAME" --script res://tests/replay.gd | tee /tmp/lieutenant_replay.log
grep -q "REPLAY result=ok" /tmp/lieutenant_replay.log
bun "${GAME}/tests/verify_sql.ts"
"$GODOT" --headless --path "$GAME" res://tests/bot.tscn | tee /tmp/lieutenant_bot.log
grep -q "BOT result=ok" /tmp/lieutenant_bot.log
