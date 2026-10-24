#!/usr/bin/env bash
# Builds the website into build/site, with the browser game in build/site/play
# and Flatmates.js (its own Godot project in flatmates/) in build/site/flatmates.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source "${ROOT}/scripts/godot_setup.sh"

rm -rf build/site
mkdir -p build/site/play
python3 "${ROOT}/site/build.py" "${ROOT}/build/site"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "build/site/play/index.html"
python3 "${ROOT}/site/build.py" --play "${ROOT}/build/site/play/index.html"
python3 "${ROOT}/scripts/fit_pages_limit.py" "${ROOT}/build/site/play"

mkdir -p build/site/flatmates
"$GODOT" --headless --path "${ROOT}/flatmates" --import
"$GODOT" --headless --path "${ROOT}/flatmates" --export-release "Web" "${ROOT}/build/site/flatmates/index.html"
python3 "${ROOT}/site/build.py" --flatmates "${ROOT}/build/site/flatmates/index.html"
python3 "${ROOT}/scripts/fit_pages_limit.py" "${ROOT}/build/site/flatmates"
