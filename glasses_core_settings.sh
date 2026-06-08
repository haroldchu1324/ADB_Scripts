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
sleep 1

echo "Done."
