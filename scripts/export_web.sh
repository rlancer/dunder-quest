#!/usr/bin/env bash
# Builds the website into build/site, with Dunder Quest (games/dunder-quest/) in build/site/play
# Flatmates.js (games/flatmates/) in build/site/flatmates/play,
# beside its page in build/site/flatmates, and Curb Your Oxidation
# (games/curb/) in build/site/curb/play, and Prince of Versions
# (games/prince/) in build/site/prince/play.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
QUEST="${ROOT}/games/dunder-quest"
FLATMATES="${ROOT}/games/flatmates"
CURB="${ROOT}/games/curb"
PRINCE="${ROOT}/games/prince"
source "${ROOT}/scripts/godot_setup.sh"

rm -rf build/site
mkdir -p build/site/play
bun "${ROOT}/site/build.ts" "${ROOT}/build/site"
"$GODOT" --headless --path "$QUEST" --export-release "Web" "${ROOT}/build/site/play/index.html"
bun "${ROOT}/site/build.ts" --play "${ROOT}/build/site/play/index.html"
bun "${ROOT}/scripts/fit_pages_limit.ts" "${ROOT}/build/site/play"

mkdir -p build/site/flatmates/play
"$GODOT" --headless --path "$FLATMATES" --import
"$GODOT" --headless --path "$FLATMATES" --export-release "Web" "${ROOT}/build/site/flatmates/play/index.html"
bun "${ROOT}/site/build.ts" --flatmates "${ROOT}/build/site/flatmates/play/index.html"
bun "${ROOT}/scripts/fit_pages_limit.ts" "${ROOT}/build/site/flatmates/play"

mkdir -p build/site/curb/play
"$GODOT" --headless --path "$CURB" --import
"$GODOT" --headless --path "$CURB" --export-release "Web" "${ROOT}/build/site/curb/play/index.html"
bun "${ROOT}/site/build.ts" --curb "${ROOT}/build/site/curb/play/index.html"
bun "${ROOT}/scripts/fit_pages_limit.ts" "${ROOT}/build/site/curb/play"

mkdir -p build/site/prince/play
"$GODOT" --headless --path "$PRINCE" --import
"$GODOT" --headless --path "$PRINCE" --export-release "Web" "${ROOT}/build/site/prince/play/index.html"
bun "${ROOT}/site/build.ts" --prince "${ROOT}/build/site/prince/play/index.html"
bun "${ROOT}/scripts/fit_pages_limit.ts" "${ROOT}/build/site/prince/play"
