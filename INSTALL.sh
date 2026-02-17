#!/bin/bash
# install.sh — Date Replacements Installer
# Run from the repo directory: bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPLESCRIPT="update_date_replacements.applescript"
WRAPPER="run_date_replacements.sh"
PLIST="com.jgdate.update.plist"
KEYCHAIN_SERVICE="com.jgdate.screenunlock"
SHORTCUT_NAME="Update Date Replacements"

echo ""
echo "====================================="
echo "  Date Replacements Installer"
echo "====================================="
echo ""

# ---------------------------
# Check required files exist
# ---------------------------
for f in "$APPLESCRIPT" "$WRAPPER" "$PLIST"; do
    if [ ! -f "$SCRIPT_DIR/$f" ]; then
        echo "ERROR: Missing file: $f"
        echo "Make sure you're running this from the repo directory."
        exit 1
    fi
done

# ---------------------------
# Step 1: Copy scripts
# ---------------------------
echo "[1/5] Copying scripts to /usr/local/bin..."
sudo cp "$SCRIPT_DIR/$APPLESCRIPT" /usr/local/bin/
sudo cp "$SCRIPT_DIR/$WRAPPER" /usr/local/bin/
sudo chmod +x /usr/local/bin/$APPLESCRIPT
sudo chmod +x /usr/local/bin/$WRAPPER
echo "      Done."

# ---------------------------
# Step 2: Keychain password
# ---------------------------
echo ""
echo "[2/5] Setting up Keychain password..."
EXISTING=$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" 2>/dev/null && echo "found" || echo "")
if [ "$EXISTING" = "found" ]; then
    echo "      Keychain entry already exists. Skipping."
    echo "      (To update: security delete-generic-password -a \"\$USER\" -s \"$KEYCHAIN_SERVICE\")"
else
    echo "      Enter your Mac login password below (input is hidden)."
    echo "      This is stored securely in your Keychain for screen unlock."
    security add-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w
    echo "      Done."
fi

# ---------------------------
# Step 3: Install plist
# ---------------------------
echo ""
echo "[3/5] Installing launchd configuration..."
if [ -f "$HOME/Library/LaunchAgents/$PLIST" ]; then
    echo "      Plist already exists. Replacing..."
    launchctl bootout gui/$(id -u)/com.jgdate.update 2>/dev/null || true
fi
cp "$SCRIPT_DIR/$PLIST" "$HOME/Library/LaunchAgents/"
echo "      Done."

# ---------------------------
# Step 4: Shortcut reminder
# ---------------------------
echo ""
echo "[4/5] macOS Shortcut setup (MANUAL STEP REQUIRED)"
echo ""
echo "      Open the Shortcuts app and create a shortcut named exactly:"
echo "      \"Update Date Replacements\""
echo ""
echo "      Add these two actions:"
echo "        1. Run Shell Script"
echo "           - Shell: /bin/zsh"
echo "           - Input: Nothing"
echo "           - Run as Administrator: Off"
echo "           - Script: osascript /usr/local/bin/update_date_replacements.applescript"
echo ""
echo "        2. Show Notification"
echo "           - Title: Date replacements updated"
echo ""

# Check if shortcut already exists
if shortcuts list 2>/dev/null | grep -q "$SHORTCUT_NAME"; then
    echo "      Shortcut \"$SHORTCUT_NAME\" already exists. Verify it's configured correctly."
else
    echo "      Shortcut not found. Please create it now before continuing."
    echo ""
    read -p "      Press Enter when the Shortcut is created... "
fi

# ---------------------------
# Step 5: Activate
# ---------------------------
echo ""
echo "[5/5] Activating scheduler..."
launchctl bootout gui/$(id -u)/com.jgdate.update 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/$PLIST"
echo "      Done."

# ---------------------------
# Done
# ---------------------------
echo ""
echo "====================================="
echo "  Installation Complete!"
echo "====================================="
echo ""
echo "  IMPORTANT — First-run permissions:"
echo "    1. System Settings > Privacy & Security > Accessibility"
echo "       > Make sure 'Shortcuts' is listed and enabled"
echo "    2. When prompted, allow Shortcuts to control System Events"
echo ""
echo "  Energy Saver:"
echo "    Set system sleep to 'Never' (display sleep is fine at any value)"
echo ""
echo "  To test right now:"
echo "    launchctl start com.jgdate.update"
echo "    (Wait ~3 min, screen will lock/unlock, then check:)"
echo "    tail -15 ~/Library/Logs/date_replacements.log"
echo ""
echo "  The automation will run once daily, within the first hour after midnight."
echo ""
