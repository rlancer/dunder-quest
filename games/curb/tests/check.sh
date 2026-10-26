#!/usr/bin/env bash
# Curb Your Oxidation's checks, as CI runs them: every plan through the
# in-game checker, the bot through every scene, then all of it against the
# real rustc (tests/verify_rust.py). Uses $GODOT if set, else fetches Godot
# the way the export scripts do.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CURB="${ROOT}/games/curb"
if [[ -z "${GODOT:-}" ]]; then
  source "${ROOT}/scripts/godot_setup.sh"
fi

"$GODOT" --headless --path "$CURB" --import
"$GODOT" --headless --path "$CURB" --script res://tests/cases.gd | tee /tmp/curb_cases.log
grep -q "result=ok" /tmp/curb_cases.log
"$GODOT" --headless --path "$CURB" res://tests/bot.tscn | tee /tmp/curb_bot.log
grep -q "BOT result=ok" /tmp/curb_bot.log
python3 "${CURB}/tests/verify_rust.py" --require
