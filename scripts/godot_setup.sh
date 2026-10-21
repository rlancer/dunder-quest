#!/usr/bin/env bash
# Sourced by the export scripts: fetches Godot and the export templates they
# need into the CI cache, then leaves GODOT pointing at the editor binary.

VERSION="4.7.2"
STABLE="${VERSION}.stable"
CACHE="${HOME}/.cache/godot-web"
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${STABLE}"
GODOT="${CACHE}/Godot_v${VERSION}-stable_linux.x86_64"
BASE_URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}-stable"
TEMPLATES=(
  web_nothreads_release.zip
  web_nothreads_debug.zip
  windows_release_x86_64.exe
  windows_debug_x86_64.exe
  linux_release.x86_64
  linux_debug.x86_64
  macos.zip
  version.txt
)

mkdir -p "$CACHE" "$TEMPLATE_DIR"
# Keep Godot from importing exported files back into the project.
mkdir -p "${ROOT}/build"
touch "${ROOT}/build/.gdignore"

if [[ ! -x "$GODOT" ]]; then
  curl -fsSL -o "${CACHE}/godot.zip" "${BASE_URL}/Godot_v${VERSION}-stable_linux.x86_64.zip"
  unzip -o "${CACHE}/godot.zip" -d "$CACHE"
  chmod +x "$GODOT"
fi

missing=()
for name in "${TEMPLATES[@]}"; do
  [[ -f "${TEMPLATE_DIR}/${name}" ]] || missing+=("templates/${name}")
done
if (( ${#missing[@]} )); then
  [[ -f "${CACHE}/templates.tpz" ]] || curl -fsSL -o "${CACHE}/templates.tpz" "${BASE_URL}/Godot_v${VERSION}-stable_export_templates.tpz"
  unzip -o "${CACHE}/templates.tpz" "${missing[@]}" -d "${CACHE}/templates-unpack"
  for path in "${missing[@]}"; do
    cp "${CACHE}/templates-unpack/${path}" "$TEMPLATE_DIR/"
  done
  rm -f "${CACHE}/templates.tpz"
fi
