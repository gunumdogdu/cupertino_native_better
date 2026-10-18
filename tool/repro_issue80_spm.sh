#!/usr/bin/env bash
# Issue #80 / PR #83 repro — a fresh SwiftPM app fails to build because
# SVGKit 3.0.0 lets CocoaLumberjack resolve to 3.10+, which requires iOS 15
# while SVGKit's own target declares a lower minimum.
#
# The example app cannot show this: its committed Package.resolved pins
# CocoaLumberjack 3.9.1. So this script creates a throwaway Flutter app
# OUTSIDE the repo that depends on THIS checkout of the plugin by path, turns
# SwiftPM on for that app only (pubspec flag — the global `flutter config` is
# not touched), deletes every Package.resolved so the versions are resolved
# from scratch, and builds for the simulator.
#
#   tool/repro_issue80_spm.sh          # fresh app, then build
#   tool/repro_issue80_spm.sh --keep   # reuse the app from the last run
#   PLUGIN_DIR=/path/to/other/checkout tool/repro_issue80_spm.sh
#
# The plugin is referenced by path, so "before" and "after" are just two runs
# of this script against a different checkout: main, then PR #83 (switch
# branch, or point PLUGIN_DIR at a `git worktree` of pr-83).
#
# The only thing it deletes outside its own temp folder is Xcode's
# DerivedData for the throwaway app itself, so the second run cannot reuse
# the first run's package checkouts.
#
# Needs Xcode 16.3 or newer to reproduce: CocoaLumberjack 3.10.0 only ships
# manifests for Swift tools 6.1+, so an older Xcode falls back to 3.9.1.
#
# Bug present: the build fails with
#     The package product 'CocoaLumberjack' requires minimum platform version
#     15.0 for the iOS platform, but this target supports 12.0
#   and the resolved CocoaLumberjack version printed at the end is 3.10 or
#   newer.
# Bug fixed:   the build succeeds and the resolved version is 3.9.x.
#
# Either way the script prints a VERDICT line at the end.
set -uo pipefail

PLUGIN_DIR="${PLUGIN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
WORK="${TMPDIR:-/tmp}/cnb_issue80_repro"
WORK="${WORK%/}"
APP="$WORK/app"
LOG="$WORK/build.log"
KEEP=0
[[ "${1:-}" == "--keep" ]] && KEEP=1

echo "plugin : $PLUGIN_DIR ($(git -C "$PLUGIN_DIR" rev-parse --abbrev-ref HEAD) @ $(git -C "$PLUGIN_DIR" rev-parse --short HEAD))"
echo "app    : $APP"
echo "manifest dependencies in this checkout:"
grep -n '\.package(url' "$PLUGIN_DIR/ios/cupertino_native_better/Package.swift" | sed 's/^/    /'
echo

if [[ $KEEP -eq 0 || ! -d "$APP" ]]; then
  rm -rf "$WORK"
  mkdir -p "$WORK"
  flutter create --platforms=ios --org dev.cnb.repro \
    --project-name issue80_repro "$APP" >/dev/null || exit 1
  cd "$APP" || exit 1

  flutter pub add cupertino_native_better --path "$PLUGIN_DIR" >/dev/null || exit 1

  # SwiftPM for this app only.
  perl -0pi -e 's/^flutter:\n/flutter:\n  config:\n    enable-swift-package-manager: true\n/m' pubspec.yaml
  grep -q 'enable-swift-package-manager: true' pubspec.yaml || {
    echo "could not enable SwiftPM in pubspec.yaml" >&2
    exit 1
  }

  # The plugin itself needs iOS 15; a fresh app targets 13 and would fail for
  # that unrelated reason before SVGKit is even looked at.
  sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' \
    ios/Runner.xcodeproj/project.pbxproj
  if [[ -f ios/Flutter/AppFrameworkInfo.plist ]]; then
    plutil -replace MinimumOSVersion -string 15.0 ios/Flutter/AppFrameworkInfo.plist
  fi
else
  cd "$APP" || exit 1
fi

# Resolve from scratch: a leftover Package.resolved would pin whatever the
# previous run picked and hide the difference between the two branches.
find ios -name Package.resolved -not -path '*/.build/*' -delete 2>/dev/null
rm -rf build ios/build
# Same for Xcode's DerivedData, which is keyed by workspace path and would
# otherwise carry the previous run's package checkouts. Only directories
# whose info.plist names this throwaway app are removed.
for plist in "$HOME"/Library/Developer/Xcode/DerivedData/Runner-*/info.plist; do
  [[ -f "$plist" ]] || continue
  if grep -q "cnb_issue80_repro/app/ios/Runner.xcworkspace" "$plist"; then
    rm -rf "$(dirname "$plist")"
  fi
done

flutter pub get >/dev/null || exit 1

echo "building (simulator, debug) — the full log is $LOG"
# The grep only trims what is echoed; its `|| true` has to stay inside the
# braces, or it would run after a failed pipeline and reset PIPESTATUS, and
# every failed build would be read as a success.
flutter build ios --simulator --debug 2>&1 | tee "$LOG" | {
  grep -E "requires minimum platform version|Resolved source packages|CocoaLumberjack|SVGKit|error:|Built build/|Xcode build done|Failed to build" || true
}
BUILD_STATUS=${PIPESTATUS[0]}

echo
echo "resolved versions:"
RESOLVED=""
while IFS= read -r f; do
  RESOLVED="$f"
done < <(find ios -name Package.resolved -not -path '*/.build/*' 2>/dev/null)
CL_VERSION="(no Package.resolved was written)"
if [[ -n "$RESOLVED" ]]; then
  CL_VERSION="$(python3 - "$RESOLVED" <<'PY'
import json, sys
pins = {p["identity"]: p["state"].get("version") for p in json.load(open(sys.argv[1])).get("pins", [])}
for name in ("cocoalumberjack", "svgkit"):
    print(f"    {name}: {pins.get(name)}", file=sys.stderr)
print(pins.get("cocoalumberjack"))
PY
)"
fi

# "no bug" needs both: the build passed AND the version that was resolved is
# one that predates the iOS 15 requirement.
CAPPED=0
if python3 -c 'import sys; v=tuple(int(x) for x in sys.argv[1].split(".")[:2]); sys.exit(0 if v < (3, 10) else 1)' "$CL_VERSION" 2>/dev/null; then
  CAPPED=1
fi

echo
if grep -q "CocoaLumberjack.*requires minimum platform version" "$LOG"; then
  echo "VERDICT: BUG PRESENT — build failed on the CocoaLumberjack platform check (resolved $CL_VERSION)."
elif [[ $BUILD_STATUS -eq 0 && $CAPPED -eq 1 ]]; then
  echo "VERDICT: no bug — build succeeded with CocoaLumberjack $CL_VERSION."
elif [[ $BUILD_STATUS -eq 0 ]]; then
  echo "VERDICT: INCONCLUSIVE — build succeeded but CocoaLumberjack resolved to $CL_VERSION, not a pre-3.10 version; read $LOG."
else
  echo "VERDICT: INCONCLUSIVE — build failed for another reason (exit $BUILD_STATUS, resolved CocoaLumberjack $CL_VERSION); read $LOG."
fi
exit "$BUILD_STATUS"
