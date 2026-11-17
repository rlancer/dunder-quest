#!/usr/bin/env bash
# Capture the bot's trailer run at 1920x1080, so the game's text (drawn at
# window resolution) is sharp in the trailer. Movie Maker records at the
# window size, and the project's window override (1440x810) beats
# --resolution, so a temporary override.cfg sets it for the capture only.
#
#   bash trailer/capture.sh                 # all six at once: the title and the
#                                           # prologue (intro), and each case (c1..c5)
#   bash trailer/capture.sh c3 case=3       # just case 3 -> trailer/captures/c3/ + c3.log
#   bash trailer/capture.sh intro prologue  # just the title and the prologue
set -euo pipefail
cd "$(dirname "$0")/.."
printf '[display]\n\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
trap 'rm -f override.cfg' EXIT

capture() {
  local name="$1"
  shift
  rm -rf "trailer/captures/$name"
  mkdir -p "trailer/captures/$name"
  godot --path . --write-movie "trailer/captures/$name/f.png" --fixed-fps 60 res://tests/trailer_run.tscn -- "$@" > "trailer/captures/$name.log"
}

if [[ $# -gt 0 ]]; then
  capture "$@"
  exit
fi
capture intro prologue &
for n in 1 2 3 4 5; do
  capture "c$n" "case=$n" &
done
wait
