#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/encode.sh"

PKG="$(cd "$HERE/.." && pwd)"
EXAMPLE="$PKG/example"
OUT="${DOCS_MEDIA_OUT:-$HOME/development/gunumdogdu.com/public/docs-media}"
UDID="${CAP_UDID:-4C83339D-23B8-4451-BB1A-D9998766296C}"
BUNDLE="${CAP_BUNDLE:-com.dlab.cupertinoNativeExample}"
WORK="/tmp/cn-capture"; mkdir -p "$WORK" "$OUT"

STATIC_IDS=(cn-button)
ANIMATED_IDS=()

boot() { xcrun simctl boot "$UDID" 2>/dev/null || true; open -a Simulator; sleep 4; }

capture_one() {
  local id="$1" kind="$2"
  local log="$WORK/$id.log"; : > "$log"
  echo ">> capturing $id ($kind)"
  ( cd "$EXAMPLE" && flutter run --dart-define=CN_CAPTURE="$id" \
      -d "$UDID" -t lib/docs_capture/capture_app.dart ) > "$log" 2>&1 &
  local frpid=$!
  local rectline=""
  for _ in $(seq 1 240); do
    rectline="$(grep -m1 'CN_CAPTURE_READY' "$log" || true)"
    [ -n "$rectline" ] && break
    sleep 1
  done
  if [ -z "$rectline" ]; then echo "!! $id: no readiness marker (see $log)"; kill $frpid 2>/dev/null || true; return 1; fi
  local rect; rect="$(echo "$rectline" | sed -n 's/.*rect=\([0-9,]*\).*/\1/p')"
  IFS=',' read -r L T W H <<< "$rect"
  echo "   rect L=$L T=$T W=$W H=$H"
  sleep 1
  if [ "$kind" = static ]; then
    xcrun simctl io "$UDID" screenshot "$WORK/$id.png"
    crop_png "$WORK/$id.png" "$OUT/$id.png" "$L" "$T" "$W" "$H"
    echo "   wrote $OUT/$id.png"
  fi
  kill $frpid 2>/dev/null || true
  pkill -f "flutter run" 2>/dev/null || true
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  sleep 1
}

boot
for id in "${STATIC_IDS[@]}"; do capture_one "$id" static; done
echo "done."
