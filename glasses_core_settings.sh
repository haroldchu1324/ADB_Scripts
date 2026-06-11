#!/bin/bash
# ============================================================
# Script: glasses_core_settings.sh
# Opens Glasses Core app info, force stops it, then opens
# Additional settings in the app.
# ============================================================

SKIP_IDS="com.google.android.apps.mobileutilities:id/search_src_text,com.google.android.apps.mobileutilities:id/search_bar"

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
    adb shell input swipe 540 1200 540 700 350
    sleep 0.3
  done

  if [ $FOUND -eq 0 ]; then
    echo "  ERROR: '$TEXT' not found after $MAX scrolls."
    return 1
  fi
}

# ============================================================
# MAIN FLOW
# ============================================================

echo "==> Checking ADB connection..."
DEVICE_STATUS=$(adb get-state 2>&1)
if [ "$DEVICE_STATUS" != "device" ]; then
  echo "ERROR: No device found or device not authorized."
  exit 1
fi

echo "==> Opening Glasses Core app info..."
adb shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.google.android.glasses.core > /dev/null
sleep 1.5

echo "==> Force stopping Glasses Core..."
adb shell am force-stop com.google.android.glasses.core
sleep 1

echo "==> Tapping 'Additional settings in the app'..."
tap_by_text "Additional settings in the app" || exit 1
sleep 3

echo "==> Tapping gear icon (Developer Settings)..."
tap_by_resource_id "com.google.android.glasses.core:id/menu_item_settings" || exit 1
sleep 1

echo "==> Tapping 'Display'..."
tap_by_text "Display" || exit 1
sleep 1

echo "==> Scrolling to find 'automatic snooze timeout'..."
scroll_until_text "automatic snooze timeout"
sleep 0.5

echo "==> Unchecking 'Enable automatic snooze timeout'..."
enable_toggle_by_label "Enable automatic snooze timeout" false
sleep 0.5

echo "==> Going back to Developer Settings..."
go_back 1
sleep 1

echo "==> Tapping 'Apps'..."
tap_by_text "Apps" || exit 1
sleep 1

echo "==> Unchecking 'Auto-launch System UI'..."
enable_toggle_by_label "Auto-launch System UI" false
sleep 0.5

echo "==> Force stopping Glasses Core..."
adb shell am force-stop com.google.android.glasses.core
sleep 1

echo "Done."
