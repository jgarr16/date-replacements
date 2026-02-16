#!/bin/bash
LOG_FILE="$HOME/Library/Logs/date_replacements.log"
SHORTCUT_NAME="Update Date Replacements"
KEYCHAIN_SERVICE="com.jgdate.screenunlock"
RUN_MARKER="/tmp/com.jgdate.lastrun"
TODAY=$(date '+%Y-%m-%d')

# Skip if already ran today
if [ -f "$RUN_MARKER" ] && [ "$(cat "$RUN_MARKER")" = "$TODAY" ]; then
    exit 0
fi

if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0) -gt 1048576 ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
fi

echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Launchd fired. Starting text replacement update." >> "$LOG_FILE"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Waking display..." >> "$LOG_FILE"
caffeinate -u -t 120 &
CAFFEINATE_PID=$!
sleep 3

# Force lock then unlock for clean state
echo "$(date '+%Y-%m-%d %H:%M:%S') - Forcing screen lock..." >> "$LOG_FILE"
osascript -e 'tell application "System Events" to keystroke "q" using {command down, control down}'
sleep 3

echo "$(date '+%Y-%m-%d %H:%M:%S') - Unlocking screen..." >> "$LOG_FILE"
PASSWORD=$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)
if [ -z "$PASSWORD" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILED: Could not retrieve password from Keychain" >> "$LOG_FILE"
    kill $CAFFEINATE_PID 2>/dev/null
    exit 1
fi
osascript -e "tell application \"System Events\" to keystroke \"$PASSWORD\""
sleep 0.5
osascript -e 'tell application "System Events" to keystroke return'
PASSWORD=""
sleep 5
echo "$(date '+%Y-%m-%d %H:%M:%S') - Unlock complete. Proceeding..." >> "$LOG_FILE"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Running Shortcut: $SHORTCUT_NAME" >> "$LOG_FILE"
OUTPUT=$(shortcuts run "$SHORTCUT_NAME" 2>&1)
EXIT_CODE=$?

echo "$(date '+%Y-%m-%d %H:%M:%S') - Exit code: $EXIT_CODE" >> "$LOG_FILE"
if [ -n "$OUTPUT" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Output: $OUTPUT" >> "$LOG_FILE"
fi

kill $CAFFEINATE_PID 2>/dev/null

if [ $EXIT_CODE -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILED" >> "$LOG_FILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS" >> "$LOG_FILE"
    echo "$TODAY" > "$RUN_MARKER"
fi
echo "========================================" >> "$LOG_FILE"
exit $EXIT_CODE
