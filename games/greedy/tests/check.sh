#!/usr/bin/env bash
# The Good, the Bad and the Greedy's checks, as CI runs them: every poster's
# solution, and every pattern shorter than it, through the game's regex
# engine (tests/replay.gd), the same patterns through JavaScript's RegExp
# (tests/verify_regex.ts), the bot through the prologue and every job, then
# every screen the game can put up, checked for text that breaks out of its
# panel (tests/layout.tscn). Uses $GODOT if set, else fetches Godot the way
# the export scripts do.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GAME="${ROOT}/games/greedy"
if [[ -z "${GODOT:-}" ]]; then
  source "${ROOT}/scripts/godot_setup.sh"
fi

"$GODOT" --headless --path "$GAME" --import
"$GODOT" --headless --path "$GAME" --script res://tests/replay.gd | tee /tmp/greedy_replay.log
grep -q "REPLAY result=ok" /tmp/greedy_replay.log
bun "${GAME}/tests/verify_regex.ts"
"$GODOT" --headless --path "$GAME" res://tests/bot.tscn | tee /tmp/greedy_bot.log
grep -q "BOT result=ok" /tmp/greedy_bot.log
"$GODOT" --headless --path "$GAME" res://tests/layout.tscn | tee /tmp/greedy_layout.log
grep -q "LAYOUT result=ok" /tmp/greedy_layout.log
