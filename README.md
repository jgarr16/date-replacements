# Presidents’ Day Date Replacements 
## Setup Guide

| | |
|---|---|
| **Created** | 2026-02-16 |
| **Reviewed** | 2026-02-16 |

#### Automation for your Apple ecosystem. 
This system automatically updates three macOS keyboard text replacements every day with ISO 8601 dates:

| Shortcut | Expands to | Example |
|----------|-----------|---------|
| `jgyst` | Yesterday's date | 2026-02-15 |
| `jgdate` | Today's date | 2026-02-16 |
| `jgtom` | Tomorrow's date | 2026-02-17 |

Type any of these shortcuts in any app on any Apple device, and macOS replaces it with the current date. Updates sync to all your Apple devices via iCloud.

---

## How It Works

Every hour, macOS checks whether dates have been updated today. If not (i.e., first check after midnight, or after a reboot), it:

1. Wakes the display (if asleep)
2. Unlocks the screen using your password (stored securely in the Keychain)
3. Opens System Settings → Keyboard → Text Replacement
4. Finds each shortcut and types the new date value (or creates it if missing)
5. Closes System Settings — iCloud sync happens automatically
6. Screen re-locks on its own after your normal timeout

The whole process takes about 2 minutes. Your other text replacements are not touched.

---

## What You Need Before Starting

- **macOS 26 Tahoe** (tested on this version; earlier versions may have different UI)
- **Admin access** to your Mac (for copying files to `/usr/local/bin`)
- **Your Mac login password** (will be stored in the Keychain — you'll be prompted to enter it during setup)
- **System sleep set to "Never"** in System Settings → Energy Saver (display sleep is fine at any value)
- **Espanso or similar text expanders**: if you have entries for `jgdate`, `jgyst`, or `jgtom`, disable them to avoid conflicts

---

## Setup Instructions

> **Important:** Run all commands in Terminal (or iTerm). Run them from the directory where you cloned this repo.

### Step 1: Copy the scripts

```bash
sudo cp update_date_replacements.applescript /usr/local/bin/
sudo cp run_date_replacements.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/update_date_replacements.applescript
sudo chmod +x /usr/local/bin/run_date_replacements.sh
```

You'll be prompted for your Mac password (this is the `sudo` prompt, not related to the Keychain step below).

### Step 2: Store your Mac login password in the Keychain

```bash
security add-generic-password -a "$USER" -s "com.jgdate.screenunlock" -w
```

This prompts you to type your Mac login password (the input is hidden — just type it and press Enter). The password is stored in your login Keychain, not in any file. The automation uses this to unlock the screen when it runs overnight.

### Step 3: Install the launchd scheduler

```bash
cp com.jgdate.update.plist ~/Library/LaunchAgents/
```

This tells macOS to run the wrapper script every hour. It loads automatically on login and survives reboots.

### Step 4: Create the macOS Shortcut (manual step)

This cannot be automated. Open the **Shortcuts** app and do the following:

1. Click **+** to create a new shortcut
2. Name it exactly: **Update Date Replacements**
3. Add a **"Run Shell Script"** action:
   - Shell: `/bin/zsh`
   - Input: `Nothing`
   - Run as Administrator: **Off**
   - In the script box, type: `osascript /usr/local/bin/update_date_replacements.applescript`
4. Add a **"Show Notification"** action below it:
   - Title: `Date replacements updated`
5. Close the shortcut (it saves automatically)

**Why a Shortcut?** macOS blocks direct AppleScript execution from launchd for security reasons. Running it through a Shortcut inherits your user permissions, which makes the UI automation work.

### Step 5: Grant permissions (first run only)

The first time the automation runs, macOS will ask you to grant two permissions:

1. **Accessibility**: System Settings → Privacy & Security → Accessibility → enable **Shortcuts**
2. **Automation**: A dialog will pop up asking if Shortcuts can control **System Events** → click **Allow**

If you don't see these prompts, go to System Settings → Privacy & Security → Accessibility and make sure Shortcuts is listed and toggled on.

### Step 6: Activate the scheduler

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jgdate.update.plist
```

The job is now running. It will check every hour and update dates once per day.

### Step 7: Test it

```bash
launchctl start com.jgdate.update
```

This forces an immediate run. Wait about 3 minutes (the screen will lock and unlock — this is normal), then check the log:

```bash
tail -15 ~/Library/Logs/date_replacements.log
```

You should see lines ending with `SUCCESS` and the correct dates. If you see an error, check the Troubleshooting section below.

---

## Repo Contents

| File | What it does |
|------|-------------|
| `update_date_replacements.applescript` | The main automation. Opens System Settings, navigates to Text Replacement, finds or creates each entry, types the new date. |
| `run_date_replacements.sh` | Wrapper that runs before the AppleScript. Wakes display, unlocks screen, calls the Shortcut, logs results, tracks whether it already ran today. |
| `com.jgdate.update.plist` | Tells macOS to run the wrapper every 3600 seconds (1 hour). Loads automatically on login. |
| `README.md` | This file. |

### Files created at runtime (not in this repo)

| File | Location | What it does |
|------|----------|-------------|
| `date_replacements.log` | `~/Library/Logs/` | Log of every run with timestamps and results. Auto-rotates at 1 MB. |
| `com.jgdate.lastrun` | `/tmp/` | Contains today's date. Prevents duplicate runs. Clears on reboot. |
| Keychain: `com.jgdate.screenunlock` | Login Keychain | Your Mac password for auto-unlock. |
| Shortcut: "Update Date Replacements" | Shortcuts app | The permission bridge you created in Step 4. |

---

## Day-to-Day Operations

**Check the log to see if it ran last night:**
```bash
tail -20 ~/Library/Logs/date_replacements.log
```

**Force it to run again right now** (e.g., after you manually changed a replacement):
```bash
rm -f /tmp/com.jgdate.lastrun && launchctl start com.jgdate.update
```

**Check if the scheduler is loaded:**
```bash
launchctl list | grep jgdate
```

**Reload after editing the plist:**
```bash
launchctl bootout gui/$(id -u)/com.jgdate.update 2>/dev/null; launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jgdate.update.plist
```

**You changed your Mac password?** Update the Keychain entry:
```bash
security delete-generic-password -a "$USER" -s "com.jgdate.screenunlock"
security add-generic-password -a "$USER" -s "com.jgdate.screenunlock" -w
```

**Check the replacements manually:** System Settings → Keyboard → Text Replacement → look for `jgdate`, `jgyst`, `jgtom`.

---

## Troubleshooting

**Error: "Can't get window 1 of process System Settings" (-1719)**

The screen was locked and the unlock failed. Most likely your Keychain password is wrong or missing. Verify it:
```bash
security find-generic-password -a "$USER" -s "com.jgdate.screenunlock" -w
```
If it prints your password correctly, try a force re-run. If it errors, re-add the password (see Day-to-Day Operations above).

**Replacements updated but not syncing to iPhone/iPad**

Give it a few minutes — iCloud sync isn't instant. If it still doesn't appear, check: System Settings → [Your Name] → iCloud and make sure keyboard/text data is syncing.

**Script runs but takes more than 5 minutes**

Normal runtime is ~2 minutes. If it hangs, System Settings probably has a dialog or alert blocking the automation. Kill it and retry:
```bash
killall "System Settings" 2>/dev/null && rm -f /tmp/com.jgdate.lastrun && launchctl start com.jgdate.update
```

**The job isn't firing at all**

Check that it's loaded:
```bash
launchctl list | grep jgdate
```
If it's not listed, load it:
```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jgdate.update.plist
```

**Text expander conflict (Espanso, TextExpander, etc.)**

If you have a text expander with an entry for `jgdate`, it will intercept the keystrokes before AppleScript can type them. Disable or delete the conflicting entry in your text expander.

---

## Uninstall

To completely remove everything:

```bash
launchctl bootout gui/$(id -u)/com.jgdate.update
sudo rm /usr/local/bin/update_date_replacements.applescript
sudo rm /usr/local/bin/run_date_replacements.sh
rm ~/Library/LaunchAgents/com.jgdate.update.plist
rm -f ~/Library/Logs/date_replacements.log
rm -f /tmp/com.jgdate.lastrun
security delete-generic-password -a "$USER" -s "com.jgdate.screenunlock"
```

Then open the Shortcuts app and delete the "Update Date Replacements" shortcut.

The text replacements themselves (`jgdate`, `jgyst`, `jgtom`) will remain in System Settings with their last values. Delete them manually if you no longer want them.

---

## Why It's Built This Way

If you're curious why this is so complex for "just updating three text fields":

- **Why UI automation?** macOS stores text replacements in a SQLite database (`~/Library/KeyboardServices/TextReplacements.db`), but editing it directly doesn't trigger iCloud sync. Only changes made through the System Settings UI trigger the TextReplacementService → CloudKit → iCloud sync chain.

- **Why a Shortcut wrapper?** Running AppleScript directly from launchd gets blocked by macOS security (TCC/Accessibility permissions). Wrapping it in a Shortcut inherits your user permissions. Building a standalone `.app` with `osacompile` also doesn't work because the code signature changes on every rebuild, invalidating permission grants.

- **Why hourly checks instead of a specific time?** `StartCalendarInterval` (launchd's "run at a specific time" feature) doesn't fire reliably on macOS 26 Tahoe. An hourly `StartInterval` with a "did I already run today?" check is more robust and self-healing after reboots.

- **Why force-lock then unlock?** We tried detecting whether the screen was locked (using Quartz CGSession API and System Events), but both methods return incorrect results when called from a launchd context. The deterministic approach — always lock, then always unlock — works reliably regardless of the screen's current state.

- **Why `entire contents`?** macOS 26's System Settings is built with SwiftUI, which has gaps in its accessibility tree. The normal `UI elements` command returns empty results for many SwiftUI groups. The `entire contents` command penetrates deeper and finds all interactive elements.
