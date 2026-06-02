#!/bin/bash
# ============================================================
# Script: open_mobileutilities.sh
# Device: Pixel 10 (Android via ADB)
# Purpose:
#   1. Opens MobileUtilities app
#   2. Types "glasses" in the search bar
#   3. Clicks the result that says "Glasses"
#   4. Clicks the result that says "Flags"
#   5. Calls override_flag <number> to override a flag
# Requirements:
#   - ADB installed on your computer
#   - USB Debugging enabled on your Pixel 10
#   - Device connected via USB (or ADB over Wi-Fi)
#   - python3 installed on your computer
# ============================================================

APP_PACKAGE="com.google.android.apps.mobileutilities"
SEARCH_BAR_ID="com.google.android.apps.mobileutilities:id/search_bar"
CLEAR_BTN_ID="com.google.android.apps.mobileutilities:id/search_close_btn"
SKIP_IDS="com.google.android.apps.mobileutilities:id/search_src_text,com.google.android.apps.mobileutilities:id/search_bar"
SETTINGS_SEARCH_ID="com.android.settings:id/search_action_bar"

# ------------------------------------------------------------
# Helper: tap_by_resource_id <resource_id>
# ------------------------------------------------------------
tap_by_resource_id() {
  local RES_ID="$1"
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null
  adb pull /sdcard/ui.xml /tmp/ui.xml > /dev/null 2>&1

  python3 - "$RES_ID" <<'EOF'
import subprocess, sys
import xml.etree.ElementTree as ET

resource_id = sys.argv[1]
tree = ET.parse("/tmp/ui.xml")
root = tree.getroot()

for node in root.iter("node"):
    if node.attrib.get("resource-id") == resource_id:
        bounds = node.attrib.get("bounds")
        coords = bounds.replace("][", ",").strip("[]").split(",")
        x = (int(coords[0]) + int(coords[2])) // 2
        y = (int(coords[1]) + int(coords[3])) // 2
        print(f"  Found '{resource_id}' -> tapping ({x}, {y})")
        subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)], check=True)
        sys.exit(0)

print(f"  ERROR: Element '{resource_id}' not found.")
sys.exit(1)
EOF
}

# ------------------------------------------------------------
# Helper: enable_toggle_by_label <label>
#   Finds a toggle by its nearby label text and only taps it
#   if it is currently off (checked=false).
#   Usage: enable_toggle_by_label "Spoken notifications"
enable_toggle_by_label() {
  local LABEL="$1"
  local DESIRED="${2:-true}"
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null
  adb pull /sdcard/ui.xml /tmp/ui.xml > /dev/null 2>&1

  python3 - "$LABEL" "$DESIRED" <<'EOF'
import subprocess, sys
import xml.etree.ElementTree as ET

label = sys.argv[1].strip().lower()
desired = sys.argv[2].strip().lower()
tree = ET.parse("/tmp/ui.xml")
root = tree.getroot()

# Find the Y center of the label text
label_y = None
label_bounds = None
for node in root.iter("node"):
    if node.attrib.get("text", "").strip().lower() == label:
        bounds = node.attrib.get("bounds")
        coords = bounds.replace("][", ",").strip("[]").split(",")
        label_y = (int(coords[1]) + int(coords[3])) // 2
        label_bounds = coords
        break

if label_y is None:
    print(f"  ERROR: Label '{label}' not found.")
    sys.exit(1)

# Find the toggle on the same row to the right (closest to label)
label_x2 = int(label_bounds[2])
best = None
best_x = float('inf')
best_checked = None

for node in root.iter("node"):
    if node.attrib.get("class", "") == "android.widget.TextView":
        continue
    bounds = node.attrib.get("bounds", "")
    if not bounds:
        continue
    coords = bounds.replace("][", ",").strip("[]").split(",")
    x1, y1, x2, y2 = int(coords[0]), int(coords[1]), int(coords[2]), int(coords[3])
    cy = (y1 + y2) // 2
    if abs(cy - label_y) < 60 and x1 >= label_x2:
        if x1 < best_x:
            best_x = x1
            best = ((x1 + x2) // 2, cy)
            best_checked = node.attrib.get("checked", "false")

if best:
    if best_checked == desired:
        print(f"  Toggle '{label}' is already '{desired}', skipping.")
        sys.exit(0)
    print(f"  Toggle '{label}' is '{best_checked}' -> tapping to set '{desired}' at {best}")
    subprocess.run(["adb", "shell", "input", "tap", str(best[0]), str(best[1])], check=True)
    sys.exit(0)

print(f"  ERROR: No toggle found next to '{label}'.")
sys.exit(1)
EOF
}

# ------------------------------------------------------------
# Helper: tap_by_text <text>
#   Finds element by visible text, skipping the search bar.
# ------------------------------------------------------------
tap_by_text() {
  local TEXT="$1"
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null
  adb pull /sdcard/ui.xml /tmp/ui.xml > /dev/null 2>&1

  python3 - "$TEXT" "$SKIP_IDS" <<'EOF'
import subprocess, sys
import xml.etree.ElementTree as ET

search_text = sys.argv[1]
skip_ids = sys.argv[2].split(",")

tree = ET.parse("/tmp/ui.xml")
root = tree.getroot()

for node in root.iter("node"):
    if node.attrib.get("resource-id", "") in skip_ids:
        continue
    if node.attrib.get("text", "").strip().lower() == search_text.strip().lower():
        bounds = node.attrib.get("bounds")
        coords = bounds.replace("][", ",").strip("[]").split(",")
        x = (int(coords[0]) + int(coords[2])) // 2
        y = (int(coords[1]) + int(coords[3])) // 2
        print(f"  Found '{search_text}' -> tapping ({x}, {y})")
        subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)], check=True)
        sys.exit(0)

print(f"  ERROR: No element with text '{search_text}' found.")
sys.exit(1)
EOF
}

# ------------------------------------------------------------
# Helper: tap_by_text <text>
#   Finds element by visible text, skipping the search bar.
# ------------------------------------------------------------
tap_by_text() {
  local TEXT="$1"
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null
  adb pull /sdcard/ui.xml /tmp/ui.xml > /dev/null 2>&1

  python3 - "$TEXT" "$SKIP_IDS" <<'EOF'
import subprocess, sys
import xml.etree.ElementTree as ET

search_text = sys.argv[1]
skip_ids = sys.argv[2].split(",")

tree = ET.parse("/tmp/ui.xml")
root = tree.getroot()

for node in root.iter("node"):
    if node.attrib.get("resource-id", "") in skip_ids:
        continue
    if node.attrib.get("text", "").strip().lower() == search_text.strip().lower():
        bounds = node.attrib.get("bounds")
        coords = bounds.replace("][", ",").strip("[]").split(",")
        x = (int(coords[0]) + int(coords[2])) // 2
        y = (int(coords[1]) + int(coords[3])) // 2
        print(f"  Found '{search_text}' -> tapping ({x}, {y})")
        subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)], check=True)
        sys.exit(0)

print(f"  ERROR: No element with text '{search_text}' found.")
sys.exit(1)
EOF
}
# ------------------------------------------------------------
# Function: navigate_settings <search_term> <result_text>
#   Opens Settings, searches for a term, clicks the matching result.
#   Usage: navigate_settings "notification read" "Notification read, reply & control"
# ------------------------------------------------------------
navigate_settings() {
  local TERM="$1"
  local RESULT="${2:-$1}"
  echo "==> Opening Settings..."
  adb shell am start -a android.settings.SETTINGS > /dev/null
  sleep 1.5

  echo "==> Tapping Settings search bar..."
  tap_by_resource_id "$SETTINGS_SEARCH_ID" || return 1
  sleep 0.5

  echo "==> Typing '$TERM'..."
  adb shell input text "$TERM"
  sleep 1

  echo "==> Clicking result '$RESULT'..."
  tap_by_text "$RESULT" || return 1
  sleep 1
}
# ------------------------------------------------------------
# Function: go_back <times>
#   Presses the back button n times.
#   Usage: go_back 3
# ------------------------------------------------------------
go_back() {
  local TIMES="${1:-1}"
  for ((i=1; i<=TIMES; i++)); do
    adb shell input keyevent KEYCODE_BACK
    sleep 0.3
  done
}

# ------------------------------------------------------------
# Function: override_flag <flag_number>
#   1. Taps the search bar and types the flag number
#   2. Clicks the 2nd option (the flag result)
#   3. Clicks "Override Flag"
#   4. Clicks "Ok"
#   5. Presses back to return to previous page
#   6. Taps search bar and clears it
#
# Usage: override_flag "45717667"
# ------------------------------------------------------------
override_flag() {
  local FLAG="$1"
  echo "==> [override_flag] Searching for flag: $FLAG"

  tap_by_resource_id "$SEARCH_BAR_ID" || return 1
  sleep 0.3
  adb shell input text "$FLAG"
  sleep 0.3

  tap_by_text "$FLAG" || return 1
  sleep 0.3

  tap_by_text "Override Flag" || return 1
  sleep 0.3

  tap_by_text "Ok" || return 1
  sleep 0.3

  go_back 

  tap_by_resource_id "$CLEAR_BTN_ID" || return 1

  echo "==> [override_flag] Done with flag: $FLAG"
}

# ------------------------------------------------------------
# Function: scroll_until_text <text> <max_scrolls>
#   Scrolls down until the given text appears on screen.
#   Usage: scroll_until_text "NotifyMe"
#          scroll_until_text "NotifyMe" 10
# ------------------------------------------------------------
scroll_until_text() {
  local TEXT="$1"
  local MAX="${2:-10}"
  local FOUND=0

  echo "==> Scrolling to find '$TEXT'..."
  for ((i=1; i<=MAX; i++)); do
    adb shell uiautomator dump /sdcard/ui.xml > /dev/null
    adb pull /sdcard/ui.xml /tmp/ui.xml > /dev/null 2>&1

    MATCH=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('/tmp/ui.xml')
for node in tree.getroot().iter('node'):
    if '${TEXT}'.lower() in node.attrib.get('text', '').lower():
        print('found')
        break
")

    if [ "$MATCH" = "found" ]; then
      echo "  Found '$TEXT' after $i scroll(s)."
      FOUND=1
      break
    fi

    echo "  Not found yet, scrolling ($i/$MAX)..."
    adb shell input swipe 540 1200 540 200 200
    sleep 0.3
  done

  if [ $FOUND -eq 0 ]; then
    echo "  ERROR: '$TEXT' not found after $MAX scrolls."
    return 0.3
  fi
}

# ------------------------------------------------------------
# Function: clear_all_apps
#   Opens recents, swipes to the leftmost screen, taps Clear all
# ------------------------------------------------------------
clear_all_apps() {
  echo "==> Clearing all recent apps..."
  adb shell input keyevent KEYCODE_APP_SWITCH
  sleep 1

  # Swipe left multiple times to get to the leftmost screen
  for ((i=1; i<=3; i++)); do
    adb shell input swipe 200 1000 900 1000 100
    sleep 0.5
  done

  sleep 1
  tap_by_text "Clear all"
  echo "==> All apps cleared."
}
# ============================================================
# MAIN FLOW
# ============================================================


echo "==> Checking ADB connection..."
DEVICE_STATUS=$(adb get-state 2>&1)
if [ "$DEVICE_STATUS" != "device" ]; then
  echo "ERROR: No device found or device not authorized."
  echo "  - Make sure your Pixel 10 is connected via USB."
  echo "  - Enable USB Debugging in Settings > Developer Options."
  exit 1
fi

clear_all_apps
sleep 1

echo "==> Launching MobileUtilities..."
adb shell monkey -p "$APP_PACKAGE" -c android.intent.category.LAUNCHER 1 > /dev/null
sleep 1.0

echo "==> Tapping search bar..."
tap_by_resource_id "$SEARCH_BAR_ID" || exit 1
sleep 0.5

# --- Starting Glasses ---

echo "==> Typing 'glasses'..."
adb shell input text "glasses"
sleep 0.3

echo "==> Clicking result 'Glasses'..."
tap_by_text "Glasses Core" || exit 1
sleep 0.3

echo "==> Clicking result 'Flags'..."
tap_by_text "Flags" || exit 1
sleep 0.3

override_flag "45723960"

override_flag "45749703"

sleep 0.3
go_back 4

# --- Starting Glasses Core ---

echo "==> Clicking result 'Glasses Core'..."
tap_by_text "Glasses Core" || exit 1
sleep 0.3

echo "==> Clicking result 'Flags'..."
tap_by_text "Flags" || exit 1
sleep 0.3

override_flag "45717667"

override_flag "45750047"

override_flag "45760770"

override_flag "45769248"

sleep 0.3

echo "==> Navigating to home screen..."
adb shell input keyevent KEYCODE_HOME
sleep 0.5

echo "==> Force stopping Glasses Core..."
adb shell am force-stop com.google.android.glasses.core
sleep 1

adb shell monkey -p com.google.android.glasses.companion -c android.intent.category.LAUNCHER 1
sleep 1

echo "==> Navigating to home screen..."
adb shell input keyevent KEYCODE_HOME
sleep 1

adb shell monkey -p com.google.android.glasses.companion -c android.intent.category.LAUNCHER 1
sleep 1

adb shell input swipe 500 600 500 800 300
sleep 2

tap_by_text "Notifications" || exit 1
sleep 1

enable_toggle_by_label "Spoken notifications" true   # turns it on
sleep 1

tap_by_text "All" || exit 1
sleep 1

enable_toggle_by_label "Allow all" true
sleep 1

scroll_until_text "NotifyMe"
sleep 1



echo "✅ ✅ ✅ ✅ ✅ ==> All done! ✅ ✅ ✅ ✅ ✅ "
echo "✅ ✅ ✅ ✅ ✅ ==> All done! ✅ ✅ ✅ ✅ ✅ "