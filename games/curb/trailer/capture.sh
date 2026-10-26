#!/usr/bin/env bash
# Capture the bot's trailer run at 1920x1080, so the game's text (drawn at
# window resolution) is sharp in the trailer. Movie Maker records at the
# window size, and the project's window override (1440x810) beats
# --resolution, so a temporary override.cfg sets it for the capture only.
#
#   bash trailer/capture.sh            # -> trailer/captures/run/ + run.log
#   bash trailer/capture.sh s5 scene=5 # -> trailer/captures/s5/ + s5.log
set -euo pipefail
cd "$(dirname "$0")/.."
name="${1:-run}"
shift || true
printf '[display]\n\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
trap 'rm -f override.cfg' EXIT
rm -rf "trailer/captures/$name"
mkdir -p "trailer/captures/$name"
godot --path . --write-movie "trailer/captures/$name/f.png" --fixed-fps 60 res://tests/trailer_run.tscn -- "$@" > "trailer/captures/$name.log"
