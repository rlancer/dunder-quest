#!/usr/bin/env bash
# A Game About Nothing's checks, as CI runs them: every slip every scene's
# cards can make, through the game's own counters (tests/replay.gd), the same
# requests to a real HTTP server with real fetch (tests/verify_http.ts), the
# bot through the prologue and every episode, then every screen the game
# can put up, checked for text that breaks out of its panel
# (tests/layout.tscn). Uses $GODOT if set, else fetches Godot the way the
# export scripts do.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GAME="${ROOT}/games/nothing"
if [[ -z "${GODOT:-}" ]]; then
  source "${ROOT}/scripts/godot_setup.sh"
fi

"$GODOT" --headless --path "$GAME" --import
"$GODOT" --headless --path "$GAME" --script res://tests/replay.gd | tee /tmp/nothing_replay.log
grep -q "REPLAY result=ok" /tmp/nothing_replay.log
bun "${GAME}/tests/verify_http.ts"
"$GODOT" --headless --path "$GAME" res://tests/bot.tscn | tee /tmp/nothing_bot.log
grep -q "BOT result=ok" /tmp/nothing_bot.log
"$GODOT" --headless --path "$GAME" res://tests/layout.tscn | tee /tmp/nothing_layout.log
grep -q "LAYOUT result=ok" /tmp/nothing_layout.log
