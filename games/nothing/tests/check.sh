#!/usr/bin/env bash
# A Game About Nothing's checks, as CI runs them: every way every scene's
# cue cards can go on, through the game's event loop (tests/replay.gd), the
# same programs through the real JavaScript engine (tests/verify_loop.ts),
# the bot through the prologue and every episode, then every screen the game
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
bun "${GAME}/tests/verify_loop.ts"
"$GODOT" --headless --path "$GAME" res://tests/bot.tscn | tee /tmp/nothing_bot.log
grep -q "BOT result=ok" /tmp/nothing_bot.log
"$GODOT" --headless --path "$GAME" res://tests/layout.tscn | tee /tmp/nothing_layout.log
grep -q "LAYOUT result=ok" /tmp/nothing_layout.log
