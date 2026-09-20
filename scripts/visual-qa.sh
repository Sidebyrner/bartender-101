#!/usr/bin/env bash
#
# Visual QA capture harness for Bartender 101 / Drinks Codex.
#
# Boots a small simulator matrix, installs both apps, and captures each key
# screen in light/dark x default/accessibility-extra-large. The status bar is
# pinned to 9:41 so the output doubles as App Store screenshots.
#
# You drive the app to each screen and press Enter; the script then captures
# all four condition combos in a couple of seconds by toggling appearance and
# Dynamic Type on the *running* app rather than relaunching it. That's the
# difference between ~6 prompts per app and ~24.
#
# Usage:
#   scripts/visual-qa.sh                 # full interactive run, all devices
#   scripts/visual-qa.sh --auto          # launch screens only, no prompts
#   scripts/visual-qa.sh --device SE     # just one device (SE | MAX | IPAD)
#   scripts/visual-qa.sh --app codex     # just one app (b101 | codex)
#
# Requires: Xcode with iOS simulators. Run from the repo root.

set -uo pipefail

OUT_DIR="${OUT_DIR:-qa-screenshots}"
DERIVED="${DERIVED:-/tmp/vqa-build}"
PROJECT="Bartender101.xcodeproj"

AUTO=0
ONLY_DEVICE=""
ONLY_APP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) AUTO=1; shift ;;
    --device) ONLY_DEVICE="$(echo "$2" | tr '[:lower:]' '[:upper:]')"; shift 2 ;;
    --app) ONLY_APP="$(echo "$2" | tr '[:upper:]' '[:lower:]')"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v xcrun >/dev/null 2>&1 || { echo "error: xcrun not found — this needs a Mac with Xcode."; exit 1; }
[[ -d "$PROJECT" ]] || { echo "error: run this from the repo root (no $PROJECT here)."; exit 1; }

UDID_RE='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'

# Resolve a device by name pattern rather than hardcoding, so this survives
# Xcode renaming its simulators every year.
find_device() {
  xcrun simctl list devices available \
    | grep -E "$1" \
    | head -1 \
    | grep -oE "$UDID_RE" \
    | head -1
}

SE_UDID="$(find_device 'iPhone SE')"
MAX_UDID="$(find_device 'iPhone .*Pro Max')"
IPAD_UDID="$(find_device 'iPad Pro .*(13|12\.9)')"
[[ -z "$IPAD_UDID" ]] && IPAD_UDID="$(find_device 'iPad Pro')"
[[ -z "$IPAD_UDID" ]] && IPAD_UDID="$(find_device 'iPad')"

# name|udid|does-landscape
DEVICES=()
[[ -n "$SE_UDID"   ]] && DEVICES+=("iPhone-SE|$SE_UDID|no")
[[ -n "$MAX_UDID"  ]] && DEVICES+=("iPhone-Pro-Max|$MAX_UDID|no")
[[ -n "$IPAD_UDID" ]] && DEVICES+=("iPad-Pro|$IPAD_UDID|yes")

if [[ ${#DEVICES[@]} -eq 0 ]]; then
  echo "error: no matching simulators available. 'xcrun simctl list devices available' shows what you have."
  exit 1
fi

# scheme|bundle-id|app-name|short
APPS=(
  "Bartender101|com.bartender101.Bartender101|Bartender101|b101"
  "DrinksCodex|com.bartender101.DrinksCodex|DrinksCodex|codex"
)

# The screens worth capturing, including the ones you never see because your
# own build has data in it.
screens_for() {
  case "$1" in
    b101) cat <<'EOS'
home-fresh|Home tab, fresh install (every card due)
browse-list|Browse tab, full deck
card-front|Browse > tap any drink (card front, unflipped)
card-back|Tap the card to flip it to the full spec
review-session|Home > Spaced Review, with a card showing
speed-drill|Home > Speed Drill, clock running
reverse-quiz|Home > Name That Drink
stats-empty|Stats tab BEFORE grading anything (empty state)
settings|Settings tab
EOS
      ;;
    codex) cat <<'EOS'
search-list|Search tab, full list
search-no-results|Type "zzzz" in search (empty state)
detail-single|Open Margarita, 1 serving
detail-batch|Same drink: servings 12, Batch toggle ON
detail-ml|Same drink: flip the unit toggle to ml
settings|Settings tab
EOS
      ;;
  esac
}

capture_conditions() {
  local udid="$1" dir="$2" screen="$3"
  mkdir -p "$dir"
  for appearance in light dark; do
    xcrun simctl ui "$udid" appearance "$appearance" >/dev/null 2>&1
    for size in large accessibility-extra-large; do
      xcrun simctl ui "$udid" content_size "$size" >/dev/null 2>&1
      sleep 1.2   # let the app re-lay-out before the shutter
      xcrun simctl io "$udid" screenshot "$dir/${screen}-${appearance}-${size}.png" >/dev/null 2>&1
    done
  done
  # leave the sim in a sane state for the next prompt
  xcrun simctl ui "$udid" appearance light >/dev/null 2>&1
  xcrun simctl ui "$udid" content_size large >/dev/null 2>&1
  echo "      captured 4 conditions"
}

# simctl has no rotate verb, so this drives the Simulator UI. It needs
# Accessibility permission for your terminal; if it's not granted the script
# says so and skips landscape rather than pretending it covered it.
rotate() {
  osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1
  osascript -e "tell application \"System Events\" to key code $1 using command down" >/dev/null 2>&1
}

ROTATE_OK=1
check_rotate() {
  if ! osascript -e 'tell application "System Events" to name of first process' >/dev/null 2>&1; then
    ROTATE_OK=0
    echo
    echo "  !! Cannot drive the Simulator UI via AppleScript (Accessibility permission)."
    echo "     Landscape will be SKIPPED — not silently, so you know it's uncovered."
    echo "     To enable: System Settings > Privacy & Security > Accessibility > add your terminal."
    echo
  fi
}

echo "Devices:"
for entry in "${DEVICES[@]}"; do
  IFS='|' read -r name udid _ <<< "$entry"
  echo "  $name  $udid"
done
echo

[[ $AUTO -eq 0 ]] && check_rotate

for entry in "${DEVICES[@]}"; do
  IFS='|' read -r dev_name udid does_landscape <<< "$entry"
  [[ -n "$ONLY_DEVICE" ]] && [[ "$(echo "$dev_name" | tr '[:lower:]' '[:upper:]')" != *"$ONLY_DEVICE"* ]] && continue

  echo "=== $dev_name ==="
  xcrun simctl boot "$udid" >/dev/null 2>&1
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1
  open -a Simulator >/dev/null 2>&1
  xcrun simctl status_bar "$udid" override \
    --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 >/dev/null 2>&1

  for app_entry in "${APPS[@]}"; do
    IFS='|' read -r scheme bundle_id app_name short <<< "$app_entry"
    [[ -n "$ONLY_APP" ]] && [[ "$short" != "$ONLY_APP" ]] && continue

    echo "  -- $scheme"
    if ! xcodebuild -project "$PROJECT" -scheme "$scheme" \
        -destination "platform=iOS Simulator,id=$udid" \
        -derivedDataPath "$DERIVED" build >/dev/null 2>&1; then
      echo "     BUILD FAILED for $scheme — skipping. Re-run without the redirect to see why:"
      echo "     xcodebuild -project $PROJECT -scheme $scheme -destination 'platform=iOS Simulator,id=$udid' build"
      continue
    fi

    app_path="$DERIVED/Build/Products/Debug-iphonesimulator/$app_name.app"
    [[ -d "$app_path" ]] || { echo "     no .app at $app_path — skipping"; continue; }

    xcrun simctl install "$udid" "$app_path" >/dev/null 2>&1
    xcrun simctl launch "$udid" "$bundle_id" >/dev/null 2>&1
    sleep 3

    dir="$OUT_DIR/$dev_name/$short"

    if [[ $AUTO -eq 1 ]]; then
      capture_conditions "$udid" "$dir" "launch"
    else
      while IFS='|' read -r key label; do
        [[ -z "$key" ]] && continue
        echo
        echo "     >> $label"
        read -r -p "        press Enter to capture (s to skip): " ans < /dev/tty
        [[ "$ans" == "s" ]] && { echo "        skipped"; continue; }
        capture_conditions "$udid" "$dir" "$key"

        if [[ "$does_landscape" == "yes" && $ROTATE_OK -eq 1 ]]; then
          rotate 124
          sleep 1.5
          xcrun simctl io "$udid" screenshot "$dir/${key}-landscape.png" >/dev/null 2>&1
          rotate 123
          sleep 1
          echo "      captured landscape"
        fi
      done < <(screens_for "$short")
    fi

    xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1
  done
done

echo
echo "Done. Screenshots in: $OUT_DIR/"
find "$OUT_DIR" -name '*.png' 2>/dev/null | wc -l | xargs echo "PNG count:"
if [[ $ROTATE_OK -eq 0 ]]; then
  echo "NOTE: landscape was not captured (see the Accessibility warning above)."
fi
echo "Send the folder to Claude for the critique pass."
