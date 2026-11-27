#!/usr/bin/env bash
# Capture the bot's trailer run at 1920x1080, so the game's text (drawn at
# window resolution) is sharp in the trailer. Movie Maker records at the
# window size, and the project's window override (1440x810) beats
# --resolution, so a temporary override.cfg sets it for the capture only.
#
#   bash trailer/capture.sh                   # all six, one after another: the title and
#                                             # the prologue (open), and each episode (e1..e5)
#   bash trailer/capture.sh e3 episode=3      # just episode 3 -> trailer/captures/e3/ + e3.log
#   bash trailer/capture.sh open prologue     # just the title and the prologue
#
# Uses $GODOT if set, else `godot` on the PATH. Recording needs a window:
# where there's no display (a cloud session), it runs under xvfb-run with
# the OpenGL renderer.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
printf '[display]\n\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
trap 'rm -f override.cfg' EXIT

RUN=("$GODOT")
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" && "$(uname -s)" == "Linux" ]]; then
  RUN=(xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --rendering-driver opengl3)
fi

capture() {
  local name="$1"
  shift
  rm -rf "trailer/captures/$name"
  mkdir -p "trailer/captures/$name"
  "${RUN[@]}" --path . --write-movie "trailer/captures/$name/f.png" --fixed-fps 60 res://tests/trailer_run.tscn -- "$@" > "trailer/captures/$name.log"
}

if [[ $# -gt 0 ]]; then
  capture "$@"
  exit
fi
# One at a time: several copies of the game recording at once can bring the
# machine down.
capture open prologue
for n in 1 2 3 4 5; do
  capture "e$n" "episode=$n"
done
