#!/usr/bin/env bash
# Makes the Play Store phone screenshots from the real app's screens:
# store/screenshots/fr-FR/phone-1.png … phone-5.png, the files
# tool/publish_play.py uploads (--screenshots).
#
#   tool/store_screenshots.sh [device]      # device: emulator-5554 by default
#
# Runs integration_test/store_screenshots_test.dart (in-memory fakes seeded
# with a made-up round in Villefranche-sur-Saône; nothing touches Firebase)
# and takes a screenshot with `adb screencap` each time the test prints
# that a screen is ready. Needs a running Android emulator with network
# (the map's tiles come from OpenFreeMap).
#
# While it runs, the device is set up for the store, then put back:
# - screen 1080 × 2160 (Play refuses a phone screenshot whose long side is
#   more than twice the short one; 1080 × 2400 is);
# - font size 100 %;
# - the status bar's demo mode: 12:00, full battery, full Wi-Fi, no
#   notification icons.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
device="${1:-emulator-5554}"
package="fr.mandarine.tourneecalendriers"
out="$root/store/screenshots/fr-FR"
adb=(adb -s "$device")

demo() { "${adb[@]}" shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }

font_scale="$("${adb[@]}" shell settings get system font_scale | tr -d '\r')"
demo_allowed="$("${adb[@]}" shell settings get global sysui_demo_allowed | tr -d '\r')"

restore() {
  demo exit || true
  "${adb[@]}" shell settings put global sysui_demo_allowed "${demo_allowed/null/0}" || true
  "${adb[@]}" shell settings put system font_scale "${font_scale/null/1.0}" || true
  "${adb[@]}" shell wm size reset || true
}
trap restore EXIT

"${adb[@]}" shell wm size 1080x2160
"${adb[@]}" shell settings put system font_scale 1.0
"${adb[@]}" shell settings put global sysui_demo_allowed 1
demo enter
demo clock -e hhmm 1200
demo battery -e level 100 -e plugged false
demo network -e wifi show -e level 4 -e fully true
demo network -e mobile hide
demo notifications -e visible false

mkdir -p "$out"
rm -f "$out"/phone-*.png
cd "$root"
# The test prints `STORE_SCREENSHOT <name> <file>` when a screen is ready,
# then waits for <file> to exist: the screenshot is taken in between.
flutter test integration_test/store_screenshots_test.dart -d "$device" 2>&1 |
  while IFS= read -r line; do
    printf '%s\n' "$line"
    if [[ "$line" =~ STORE_SCREENSHOT\ (phone-[0-9]+)\ ([^[:space:]]+) ]]; then
      name="${BASH_REMATCH[1]}"
      "${adb[@]}" exec-out screencap -p >"$out/$name.png"
      "${adb[@]}" shell run-as "$package" touch "${BASH_REMATCH[2]}"
      echo ">>> $out/$name.png"
    fi
  done

count="$(find "$out" -name 'phone-*.png' | wc -l)"
if [[ "$count" -ne 5 ]]; then
  echo "Expected 5 screenshots in $out, found $count." >&2
  exit 1
fi
echo "5 screenshots in $out"
