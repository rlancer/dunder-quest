#!/usr/bin/env bash
# Yes, Shell!'s checks, as CI runs them: every ticket's solution, and every
# line shorter than it, through the game's shell (tests/replay.gd), the
# same lines through the real bash and coreutils (tests/verify_shell.ts),
# the bot through the prologue and every shift, then every screen the game
# can put up, checked for text that breaks out of its panel
# (tests/layout.tscn). Uses $GODOT if set, else fetches Godot the way the
# export scripts do.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GAME="${ROOT}/games/shell"
if [[ -z "${GODOT:-}" ]]; then
  source "${ROOT}/scripts/godot_setup.sh"
fi

"$GODOT" --headless --path "$GAME" --import
"$GODOT" --headless --path "$GAME" --script res://tests/replay.gd | tee /tmp/shell_replay.log
grep -q "REPLAY result=ok" /tmp/shell_replay.log
bun "${GAME}/tests/verify_shell.ts"
"$GODOT" --headless --path "$GAME" res://tests/bot.tscn | tee /tmp/shell_bot.log
grep -q "BOT result=ok" /tmp/shell_bot.log
"$GODOT" --headless --path "$GAME" res://tests/layout.tscn | tee /tmp/shell_layout.log
grep -q "LAYOUT result=ok" /tmp/shell_layout.log
