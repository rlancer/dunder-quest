#!/usr/bin/env bash
# Builds the website into build/site, with Dunder Quest (games/dunder-quest/) in build/site/play
# Flatmates.js (games/flatmates/) in build/site/flatmates/play,
# beside its page in build/site/flatmates, and Curb Your Oxidation
# (games/curb/) in build/site/curb/play.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
QUEST="${ROOT}/games/dunder-quest"
FLATMATES="${ROOT}/games/flatmates"
CURB="${ROOT}/games/curb"
source "${ROOT}/scripts/godot_setup.sh"

rm -rf build/site
mkdir -p build/site/play
python3 "${ROOT}/site/build.py" "${ROOT}/build/site"
"$GODOT" --headless --path "$QUEST" --export-release "Web" "${ROOT}/build/site/play/index.html"
python3 "${ROOT}/site/build.py" --play "${ROOT}/build/site/play/index.html"
python3 "${ROOT}/scripts/fit_pages_limit.py" "${ROOT}/build/site/play"

mkdir -p build/site/flatmates/play
"$GODOT" --headless --path "$FLATMATES" --import
"$GODOT" --headless --path "$FLATMATES" --export-release "Web" "${ROOT}/build/site/flatmates/play/index.html"
python3 "${ROOT}/site/build.py" --flatmates "${ROOT}/build/site/flatmates/play/index.html"
python3 "${ROOT}/scripts/fit_pages_limit.py" "${ROOT}/build/site/flatmates/play"

mkdir -p build/site/curb/play
"$GODOT" --headless --path "$CURB" --import
"$GODOT" --headless --path "$CURB" --export-release "Web" "${ROOT}/build/site/curb/play/index.html"
python3 "${ROOT}/site/build.py" --curb "${ROOT}/build/site/curb/play/index.html"
python3 "${ROOT}/scripts/fit_pages_limit.py" "${ROOT}/build/site/curb/play"
