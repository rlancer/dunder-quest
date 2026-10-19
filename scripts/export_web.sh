#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="4.7.2"
STABLE="${VERSION}.stable"
CACHE="${HOME}/.cache/godot-web"
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${STABLE}"
GODOT="${CACHE}/Godot_v${VERSION}-stable_linux.x86_64"
BASE_URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}-stable"

mkdir -p "$CACHE" "$TEMPLATE_DIR" build/web

if [[ ! -x "$GODOT" ]]; then
  curl -fsSL -o "${CACHE}/godot.zip" "${BASE_URL}/Godot_v${VERSION}-stable_linux.x86_64.zip"
  unzip -o "${CACHE}/godot.zip" -d "$CACHE"
  chmod +x "$GODOT"
fi

if [[ ! -f "${TEMPLATE_DIR}/web_nothreads_release.zip" ]]; then
  curl -fsSL -o "${CACHE}/templates.tpz" "${BASE_URL}/Godot_v${VERSION}-stable_export_templates.tpz"
  unzip -o "${CACHE}/templates.tpz" "templates/web_nothreads_release.zip" "templates/web_nothreads_debug.zip" "templates/version.txt" -d "${CACHE}/templates-unpack"
  cp "${CACHE}/templates-unpack/templates/web_nothreads_release.zip" "$TEMPLATE_DIR/"
  cp "${CACHE}/templates-unpack/templates/web_nothreads_debug.zip" "$TEMPLATE_DIR/"
  cp "${CACHE}/templates-unpack/templates/version.txt" "$TEMPLATE_DIR/"
fi

"$GODOT" --headless --path "$ROOT" --export-release "Web" "build/web/index.html"
python3 "${ROOT}/scripts/fit_pages_limit.py" "${ROOT}/build/web"
