#!/bin/bash
# ============================================================
# Script: TPLinux.sh
# Device: Pixel 10 (Android via ADB)
# ============================================================

APP_PACKAGE="com.google.android.apps.mobileutilities"
APK_NAME="mobileutilities_334_alldpi_minSdk21_arm64-v8a_releasekey_mobileutilities.android_20250514_RC00.apk"
SEARCH_BAR_ID="com.google.android.apps.mobileutilities:id/search_bar"
CLEAR_BTN_ID="com.google.android.apps.mobileutilities:id/search_close_btn"
SKIP_IDS="com.google.android.apps.mobileutilities:id/search_src_text,com.google.android.apps.mobileutilities:id/search_bar"

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
# Helper: enable_toggle_by_label <label> [true|false]
# ------------------------------------------------------------
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
    node_text = node.attrib.get("text", "") or node.attrib.get("content-desc", "")
    if node_text.strip().lower() == search_text.strip().lower():
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
# Helper: tap_by_text_partial <text>
#   Finds element whose text contains the given string (case-insensitive),
#   skipping the search bar.
# ------------------------------------------------------------
tap_by_text_partial() {
  local TEXT="$1"
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null
  adb pull /sdcard/ui.xml /tmp/ui.xml > /dev/null 2>&1

  python3 - "$TEXT" "$SKIP_IDS" <<'EOF'
import subprocess, sys
import xml.etree.ElementTree as ET

search_text = sys.argv[1].strip().lower()
skip_ids = sys.argv[2].split(",")

tree = ET.parse("/tmp/ui.xml")
root = tree.getroot()

for node in root.iter("node"):
    if node.attrib.get("resource-id", "") in skip_ids:
        continue
    node_text = node.attrib.get("text", "") or node.attrib.get("content-desc", "")
    if search_text in node_text.strip().lower():
        bounds = node.attrib.get("bounds")
        coords = bounds.replace("][", ",").strip("[]").split(",")
        x = (int(coords[0]) + int(coords[2])) // 2
        y = (int(coords[1]) + int(coords[3])) // 2
        print(f"  Found (partial) '{search_text}' -> tapping ({x}, {y})")
        subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)], check=True)
        sys.exit(0)

print(f"  ERROR: No element containing '{search_text}' found.")
sys.exit(1)
EOF
}

# ------------------------------------------------------------
# Helper: go_back <times>
# ------------------------------------------------------------
go_back() {
  local TIMES="${1:-1}"
  for ((i=1; i<=TIMES; i++)); do
    adb shell input keyevent KEYCODE_BACK
    sleep 0.3
  done
}

# ------------------------------------------------------------
# Helper: scroll_until_text <text> [max_scrolls]
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
    return 1
  fi
}

# ------------------------------------------------------------
# Function: install_mobile_utilities
#   Installs Mobile Utilities APK if not already installed.
#   Looks for the APK in the same directory as this script.
# ------------------------------------------------------------
install_mobile_utilities() {
  echo "==> Checking if Mobile Utilities is already installed..."
  INSTALLED=$(adb shell pm list packages | grep "$APP_PACKAGE")
  if [ -n "$INSTALLED" ]; then
    echo "  Mobile Utilities is already installed, skipping."
    return 0
  fi

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  APK_PATH="$SCRIPT_DIR/$APK_NAME"

  if [ ! -f "$APK_PATH" ]; then
    echo "  ERROR: APK not found at $APK_PATH"
    echo "  Please download the APK and place it next to this script:"
    echo "    $APK_NAME"
    exit 1
  fi

  echo "==> Installing Mobile Utilities from $APK_PATH ..."
  adb install -r -d -g "$APK_PATH"
  if [ $? -ne 0 ]; then
    echo "  ERROR: Installation failed."
    exit 1
  fi
  echo "  Mobile Utilities installed successfully."
}

# ------------------------------------------------------------
# Function: dismiss_google_account_dialog
#   After launching the app, a "Mobile Utilities wants access
#   to your Google account" dialog may appear. Scrolls down
#   and taps "Continue" if found, skips silently if not.
# ------------------------------------------------------------
dismiss_google_account_dialog() {
  echo "==> Checking for Google account permission dialog..."
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null
  adb pull /sdcard/ui.xml /tmp/ui.xml > /dev/null 2>&1

  FOUND=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('/tmp/ui.xml')
for node in tree.getroot().iter('node'):
    if 'wants access to your google account' in node.attrib.get('text', '').lower():
        print('found')
        break
")

  if [ "$FOUND" != "found" ]; then
    echo "  No permission dialog found, skipping."
    return 0
  fi

  echo "  Dialog found. Scrolling down to reveal Continue button..."
  adb shell input swipe 540 1200 540 600 300
  sleep 0.5

  echo "  Tapping 'Continue'..."
  tap_by_text "Continue" || return 1
  sleep 1
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

install_mobile_utilities

echo "==> Launching Mobile Utilities..."
adb shell monkey -p "$APP_PACKAGE" -c android.intent.category.LAUNCHER 1 > /dev/null
sleep 2

dismiss_google_account_dialog

echo "==> Tapping search bar..."
tap_by_resource_id "$SEARCH_BAR_ID" || exit 1
sleep 0.5

echo "==> Typing 'Glasses Core'..."
adb shell input text "Glasses%sCore"
sleep 0.5

echo "==> Clicking 'Glasses Core'..."
tap_by_text "Glasses Core" || exit 1
sleep 0.5

echo "==> Clicking 'Flags'..."
tap_by_text "Flags" || exit 1
sleep 0.5

echo "==> Typing flag 45723960 in search bar..."
tap_by_resource_id "$SEARCH_BAR_ID" || exit 1
sleep 0.3
adb shell input text "45723960"
sleep 0.5

echo "==> Clicking flag result '45723960'..."
tap_by_text_partial "45723960" || exit 1
sleep 2

echo "==> Clicking '✏️ OVERRIDE FLAG'..."
tap_by_text "✏️ OVERRIDE FLAG" || exit 1
sleep 0.5

echo "==> Checking current flag value..."
adb shell uiautomator dump /sdcard/ui.xml > /dev/null
adb pull /sdcard/ui.xml /tmp/ui.xml > /dev/null 2>&1

CURRENT_VALUE=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('/tmp/ui.xml')
for node in tree.getroot().iter('node'):
    if node.attrib.get('text', '').strip().lower() == 'true':
        print('true')
        break
")

if [ "$CURRENT_VALUE" = "true" ]; then
  echo "  Value is 'true', switching to 'false'..."
  tap_by_text "true" || exit 1
  sleep 0.5
  tap_by_text "false" || exit 1
  sleep 0.5
else
  echo "  Value is already 'false', skipping dropdown."
fi

echo "==> Clicking 'Ok'..."
tap_by_text "OK" || exit 1
sleep 0.5

echo "==> Going back to flags search page..."
go_back 1
sleep 0.5

echo "==> Clearing search bar and typing 45749703..."
tap_by_resource_id "$CLEAR_BTN_ID" || exit 1
sleep 0.3
adb shell input text "45749703"
sleep 0.5

echo "==> Clicking flag result '45749703'..."
tap_by_text_partial "45749703" || exit 1
sleep 2

echo "==> Clicking '✏️ OVERRIDE FLAG'..."
tap_by_text "✏️ OVERRIDE FLAG" || exit 1
sleep 0.5

echo "==> Tapping value input and typing 0..."
tap_by_resource_id "com.google.android.apps.mobileutilities:id/override_value_long" || exit 1
sleep 0.3
adb shell input keyevent KEYCODE_CTRL_A
sleep 0.2
adb shell input text "0"
sleep 0.3

echo "==> Clicking 'OK'..."
tap_by_text "OK" || exit 1
sleep 0.5

echo "Done."
