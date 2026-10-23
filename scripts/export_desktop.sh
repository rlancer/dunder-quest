#!/usr/bin/env bash
# Exports the Windows, macOS and Linux builds and zips them into
# build/downloads, with a SHA256SUMS.txt beside them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source "${ROOT}/scripts/godot_setup.sh"

rm -rf build/desktop build/downloads
mkdir -p build/desktop/windows build/desktop/linux build/desktop/macos build/downloads

"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "build/desktop/windows/Dunder Quest.exe"
"$GODOT" --headless --path "$ROOT" --export-release "Linux" "build/desktop/linux/dunder-quest.x86_64"
"$GODOT" --headless --path "$ROOT" --export-release "macOS" "build/desktop/macos/dunder-quest-macos.zip"

for path in "build/desktop/windows/Dunder Quest.exe" build/desktop/linux/dunder-quest.x86_64 build/desktop/macos/dunder-quest-macos.zip; do
  [[ -s "$path" ]] || { echo "export missing: $path" >&2; exit 1; }
done

chmod +x build/desktop/linux/dunder-quest.x86_64
(cd build/desktop/windows && zip -q -9 ../../downloads/dunder-quest-windows.zip "Dunder Quest.exe")
(cd build/desktop/linux && zip -q -9 ../../downloads/dunder-quest-linux.zip dunder-quest.x86_64)
cp build/desktop/macos/dunder-quest-macos.zip build/downloads/
(cd build/downloads && sha256sum *.zip > SHA256SUMS.txt && cat SHA256SUMS.txt && ls -la)
