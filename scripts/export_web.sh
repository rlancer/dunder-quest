#!/usr/bin/env bash
# Builds the website into build/site, with Dunder Quest (games/dunder-quest/) in build/site/play
# Flatmates.js (games/flatmates/) in build/site/flatmates/play,
# beside its page in build/site/flatmates, and Curb Your Oxidation
# (games/curb/) in build/site/curb/play, and Mission Silicon, a web app
# (games/mission-silicon/web/, built with bun and Vite, not Godot), in
# build/site/mission-silicon/play, with the Human Backend
# (games/mission-silicon/human/), a different game on the same subject, in
# build/site/mission-silicon/human, and Three Ways In
# (games/mission-silicon/ways/), three sketches of how to teach it, in
# build/site/mission-silicon/ways.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
QUEST="${ROOT}/games/dunder-quest"
FLATMATES="${ROOT}/games/flatmates"
CURB="${ROOT}/games/curb"
MISSION="${ROOT}/games/mission-silicon"
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

mkdir -p build/site/mission-silicon/play
(cd "${MISSION}/web" && bun install --frozen-lockfile && bun run build)
cp -r "${MISSION}/web/dist/." build/site/mission-silicon/play/
bun "${ROOT}/site/build.ts" --mission-silicon "${ROOT}/build/site/mission-silicon/play/index.html"

mkdir -p build/site/mission-silicon/human
(cd "${MISSION}/human" && bun install --frozen-lockfile && bun run build)
cp -r "${MISSION}/human/dist/." build/site/mission-silicon/human/

mkdir -p build/site/mission-silicon/ways
(cd "${MISSION}/ways" && bun install --frozen-lockfile && bun run build)
cp -r "${MISSION}/ways/dist/." build/site/mission-silicon/ways/
