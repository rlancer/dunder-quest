#!/usr/bin/env bash
# Builds the website into build/site, with the browser game in build/site/play.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source "${ROOT}/scripts/godot_setup.sh"

rm -rf build/site
mkdir -p build/site/play
python3 "${ROOT}/site/build.py" "${ROOT}/build/site"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "build/site/play/index.html"
python3 "${ROOT}/scripts/fit_pages_limit.py" "${ROOT}/build/site/play"
