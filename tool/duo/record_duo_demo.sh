#!/usr/bin/env bash
# Records the iPhone Duo showcase (example/lib/demos/iphone_duo_demo.dart) in
# Device Hub — device frame, fold animation and all — for the README, pub.dev
# and the website.
#
# Before running:
#   1. Boot the iPhone Duo simulator and open it in Device Hub (Xcode 27.1).
#   2. Run the showcase on it:
#        cd example && flutter run -d <udid> -t lib/duo_probe_entry.dart \
#          --dart-define=PAGE=duo --dart-define=TAB=0
#   3. Give your terminal Accessibility and Screen Recording permission.
#   4. Leave the device in its natural orientation (outer display portrait);
#      the script ends in the same orientation.
#
#   tool/duo/record_duo_demo.sh [output-dir]      (default: misc/screenshots)
#
# Writes iphone_duo_demo.mp4 and iphone_duo_preview.gif. Poses and taps are
# driven through Device Hub's accessibility tree by duo_control.swift.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$HERE/../../misc/screenshots}"
WORK="${TMPDIR:-/tmp}"; WORK="${WORK%/}/cnb_duo_recording"
mkdir -p "$WORK" "$OUT"

# duo_control: build once per run.
swiftc -O -o "$WORK/duo_control" "$HERE/duo_control.swift"
duo() { "$WORK/duo_control" "$@" >/dev/null; }

# Apple's marketing status bar.
UDID="$(xcrun simctl list devices booted | sed -n 's/.*iPhone Duo (\([0-9A-F-]*\)).*/\1/p' | head -1)"
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged \
  --batteryLevel 100 --wifiBars 3 --cellularMode active --cellularBars 4

# A clean canvas: no sidebar, a large window, the device zoomed to fit, the
# showcase on its first tab, the device closed.
duo "Closed"
"$WORK/duo_control" "Hide Sidebar" >/dev/null 2>&1 || true
osascript \
  -e 'tell application "System Events" to tell process "DeviceHub"' \
  -e 'set frontmost to true' \
  -e 'set w to first window whose name contains "iPhone Duo"' \
  -e 'perform action "AXRaise" of w' \
  -e 'set position of w to {56, 40}' \
  -e 'set size of w to {1400, 930}' \
  -e 'delay 0.5' \
  -e 'try' \
  -e 'click menu item "Zoom to Fit" of menu "View" of menu bar 1' \
  -e 'end try' \
  -e 'end tell' >/dev/null
duo "Hinge" || true
sleep 2

# Keep Device Hub above every other window while recording, so nothing else
# on the desktop can end up in the capture area. Restored at the end.
menu_mark() {
  osascript -e 'tell application "System Events" to tell process "DeviceHub"' \
    -e 'return value of attribute "AXMenuItemMarkChar" of menu item "Stay On Top" of menu "Window" of menu bar 1' \
    -e 'end tell' 2>/dev/null || true
}
toggle_stay_on_top() {
  osascript -e 'tell application "System Events" to tell process "DeviceHub"' \
    -e 'set frontmost to true' -e 'delay 0.3' \
    -e 'click menu item "Stay On Top" of menu "Window" of menu bar 1' \
    -e 'end tell' >/dev/null
}
PINNED=0
if [[ "$(menu_mark)" != "✓" ]]; then
  toggle_stay_on_top
  PINNED=1
fi
restore_stay_on_top() {
  if [[ $PINNED == 1 ]]; then
    toggle_stay_on_top || true
    PINNED=0
    echo "Stay On Top restored: $(menu_mark)"
  fi
}
trap restore_stay_on_top EXIT

# The device's extent across every pose, measured in this window at this
# size, with room for the partially open frame and the bezel: closed about
# 286x400 pt, open landscape 552x396 (wider while folding), portrait 394x556.
FRAME="376,120,700,680"
echo "recording $FRAME"

RAW="$WORK/raw.mov"
rm -f "$RAW"
# screencapture records the mouse pointer: park it in the bottom-left corner,
# outside the capture area.
osascript -l JavaScript \
  -e 'ObjC.import("CoreGraphics"); $.CGWarpMouseCursorPosition({x: 30, y: 940})' >/dev/null
screencapture -v -V 40 -R "$FRAME" "$RAW" &
REC=$!
# screencapture takes a few seconds to start writing frames.
sleep 5

# Choreography (about 32 s). The closed hold is long because screencapture's
# start time varies; the encode below drops the first 2 s.
sleep 6                           # closed: vertical rail on the outer display
duo "Open";           sleep 4     # unfold: inner display, landscape, rail
duo "Partially Open"; sleep 3     # book pose
duo "Studio";         sleep 3.5   # list beside the track, split at the fold
duo "Rotate Right";   sleep 4     # tabletop: artwork above, controls below
duo "Open";           sleep 3     # flat portrait: bottom tab bar
duo "Rotate Right"; duo "Rotate Right"; duo "Rotate Right"
duo "Closed";         sleep 3     # back to the outer display

wait "$REC" || true
restore_stay_on_top
xcrun simctl status_bar "$UDID" clear

# Encode, dropping the lead-in (screencapture starts at a variable point in
# the first seconds): H.264 MP4 for the website, GIF for the README.
ffmpeg -v error -y -ss 2 -i "$RAW" -c:v libx264 -pix_fmt yuv420p -crf 20 \
  -movflags +faststart "$OUT/iphone_duo_demo.mp4"
ffmpeg -v error -y -ss 2 -i "$RAW" \
  -vf "fps=12,scale=520:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=sierra2_4a" \
  "$OUT/iphone_duo_preview.gif"
ls -la "$OUT/iphone_duo_demo.mp4" "$OUT/iphone_duo_preview.gif"
