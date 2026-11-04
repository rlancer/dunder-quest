#!/usr/bin/env bash
# Mission Silicon's checks: every episode's data proves its lesson in the
# simulation, every curriculum module has an episode, and the bot plays every
# episode through the real UI. Uses $GODOT if set, else fetches Godot the way
# the export scripts do.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GAME="${ROOT}/games/mission-silicon"
if [[ -z "${GODOT:-}" ]]; then
  source "${ROOT}/scripts/godot_setup.sh"
fi
LOGS="$(mktemp -d)"

"$GODOT" --headless --path "$GAME" --import
"$GODOT" --headless --path "$GAME" --script res://tests/coverage.gd | tee "$LOGS/coverage.log"
grep -q "COVERAGE result=ok" "$LOGS/coverage.log"
"$GODOT" --headless --path "$GAME" --script res://tests/cases.gd | tee "$LOGS/cases.log"
grep -q "CASES result=ok" "$LOGS/cases.log"
"$GODOT" --headless --path "$GAME" res://tests/smoke.tscn | tee "$LOGS/smoke.log"
grep -q "SMOKE result=ok" "$LOGS/smoke.log"
"$GODOT" --headless --path "$GAME" res://tests/bot.tscn | tee "$LOGS/bot.log"
grep -q "BOT result=ok" "$LOGS/bot.log"
