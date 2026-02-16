#!/usr/bin/osascript
-- update_date_replacements.applescript
-- Updates macOS Text Replacement entries via System Settings UI automation.
-- Targets macOS 26 Tahoe.
--
-- Strategy:
--   1. Open System Settings > Keyboard
--   2. Click "Text Replacements..." button (found via entire contents)
--   3. For each of jgdate, jgyst, jgtom:
--      - Search the sheet's entire contents for a text field matching the shortcut
--      - If found: click the replacement text field, select all, type new value
--      - If not found: click "+", type shortcut, tab, type replacement, return
--   4. Click Done
--
-- Because changes go through the UI, they properly trigger iCloud sync.
--
-- Usage: osascript /usr/local/bin/update_date_replacements.applescript

--------------------------------------------------------------------------------
-- DATE CALCULATIONS
--------------------------------------------------------------------------------
on zeroPad(n)
	if n < 10 then
		return "0" & (n as text)
	else
		return n as text
	end if
end zeroPad

on isoDate(theDate)
	set y to year of theDate as text
	set m to my zeroPad(month of theDate as integer)
	set d to my zeroPad(day of theDate)
	return y & "-" & m & "-" & d
end isoDate

set today to current date
set yesterday to today - (1 * days)
set tomorrow to today + (1 * days)

set todayStr to my isoDate(today)
set yesterdayStr to my isoDate(yesterday)
set tomorrowStr to my isoDate(tomorrow)

-- {shortcut, new_replacement_value}
set replacements to {{"jgyst", yesterdayStr}, {"jgdate", todayStr}, {"jgtom", tomorrowStr}}

log "Starting: jgyst=" & yesterdayStr & ", jgdate=" & todayStr & ", jgtom=" & tomorrowStr

--------------------------------------------------------------------------------
-- STEP 1: Open System Settings > Keyboard
--------------------------------------------------------------------------------
tell application "System Settings"
	if it is running then quit
end tell
delay 1.5

do shell script "open x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
delay 4
tell application "System Settings" to activate
delay 1

--------------------------------------------------------------------------------
-- STEP 2: Click "Text Replacements..." button
-- Uses 'entire contents' to find the button by searching for
-- "Input Sources" static text, then clicking the 2nd button after it.
--------------------------------------------------------------------------------
tell application "System Events"
	tell process "System Settings"
		set frontmost to true
		delay 0.5

		set sg to splitter group 1 of group 1 of window 1
		set sa to scroll area 1 of group 1 of group 3 of sg

		-- Find Text Replacements button: 2nd button after "Input Sources" static text
		set allItems to entire contents of sa
		set foundIS to false
		set btnCount to 0
		set targetBtn to missing value

		repeat with i from 1 to count of allItems
			set itm to item i of allItems
			set itmClass to class of itm as text
			set itmName to ""
			try
				set itmName to name of itm as text
			end try

			if itmName is "Input Sources" and itmClass contains "static text" then
				set foundIS to true
			end if

			if foundIS and itmClass contains "button" then
				set itmRole to ""
				try
					set itmRole to role description of itm
				end try
				if itmRole is "button" then
					set btnCount to btnCount + 1
					if btnCount is 2 then
						set targetBtn to itm
						exit repeat
					end if
				end if
			end if
		end repeat

		if targetBtn is missing value then
			log "ERROR: Could not find Text Replacements button"
			tell application "System Settings" to quit
			error "Could not find Text Replacements button"
		end if

		click targetBtn
		delay 3
		log "Text Replacements sheet opened"
	end tell
end tell

--------------------------------------------------------------------------------
-- STEP 3: Update each date replacement
--------------------------------------------------------------------------------
tell application "System Events"
	tell process "System Settings"

		set theSheet to sheet 1 of window 1
		set sheetItems to entire contents of theSheet

		-- Identify the +, -, and Done buttons.
		-- From probing: near the end of entire contents, we have:
		--   sort button "Replace", sort button "With",
		--   button (add), button (remove), scroll bar stuff, button (Done)
		-- We'll find them by role.
		set addButton to missing value
		set doneButton to missing value
		set foundSortButtons to 0

		repeat with i from 1 to count of sheetItems
			set itm to item i of sheetItems
			set itmRole to ""
			try
				set itmRole to role description of itm
			end try

			-- The sort buttons ("Replace", "With") come before +/-/Done
			if itmRole is "sort button" then
				set foundSortButtons to foundSortButtons + 1
			end if

			-- After both sort buttons, the next regular buttons are +, -, then Done
			if foundSortButtons >= 2 and itmRole is "button" then
				if addButton is missing value then
					set addButton to itm
				else if doneButton is missing value then
					-- skip the minus button
					set doneButton to itm
				end if
			end if
		end repeat

		-- Actually, let me re-find: after sort buttons, buttons are: [add] [remove] [scroll stuff] [Done]
		-- So Done is the LAST button. Let me find it more carefully.
		-- Reset and find the last button in sheet contents.
		set allSheetButtons to {}
		repeat with i from 1 to count of sheetItems
			set itm to item i of sheetItems
			set itmClass to class of itm as text
			set itmRole to ""
			try
				set itmRole to role description of itm
			end try
			if itmRole is "button" then
				set end of allSheetButtons to itm
			end if
		end repeat

		-- Last button = Done, first non-scroll button after sort = Add
		set doneButton to last item of allSheetButtons

		-- Find add button: first button with role "button" after the sort buttons
		set addButton to missing value
		set passedSort to false
		repeat with i from 1 to count of sheetItems
			set itm to item i of sheetItems
			set itmRole to ""
			try
				set itmRole to role description of itm
			end try
			if itmRole is "sort button" then set passedSort to true
			if passedSort and itmRole is "button" then
				set addButton to itm
				exit repeat
			end if
		end repeat

		log "Found Add button and Done button"

		-- Now process each replacement
		repeat with entry in replacements
			set shortcut to item 1 of entry
			set newValue to item 2 of entry

			-- Re-read sheet contents (they may shift after edits)
			set sheetItems to entire contents of theSheet

			-- Search for a text field whose value matches the shortcut
			set foundShortcut to false
			set replacementField to missing value

			repeat with i from 1 to (count of sheetItems) - 1
				set itm to item i of sheetItems
				set itmClass to class of itm as text
				if itmClass contains "text field" then
					set itmVal to ""
					try
						set itmVal to value of itm as text
					end try
					if itmVal is shortcut then
						-- Found the shortcut field. The replacement value field
						-- is the next text field in the list.
						repeat with j from (i + 1) to count of sheetItems
							set nextItm to item j of sheetItems
							set nextClass to class of nextItm as text
							if nextClass contains "text field" then
								set replacementField to nextItm
								exit repeat
							end if
						end repeat
						set foundShortcut to true
						exit repeat
					end if
				end if
			end repeat

			if foundShortcut and replacementField is not missing value then
				-- EDIT IN-PLACE: click the replacement field, select all, type new value
				log "Editing " & shortcut & " in-place"

				-- Click the replacement text field
				click replacementField
				delay 0.3

				-- Triple-click to select all text in the field
				-- (Cmd+A might select all fields, so triple-click is safer)
				tell replacementField
					-- Use Cmd+A to select all text in the focused field
					set focused to true
				end tell
				delay 0.2
				keystroke "a" using command down
				delay 0.2

				-- Type the new value (replaces selected text)
				keystroke newValue
				delay 0.3

				-- Press Tab to confirm and move to next field
				keystroke tab
				delay 0.3

				log "Updated " & shortcut & " → " & newValue

			else
				-- NOT FOUND: add a new entry
				log "Adding new entry for " & shortcut

				click addButton
				delay 1.0

				-- After clicking +, re-read contents to find the new empty text fields.
				-- The new row will have an empty text field for the shortcut.
				set sheetItems to entire contents of theSheet
				set emptyField to missing value
				repeat with idx from 1 to count of sheetItems
					set itm to item idx of sheetItems
					set itmClass to class of itm as text
					if itmClass contains "text field" then
						set itmVal to ""
						try
							set itmVal to value of itm as text
						end try
						if itmVal is "" or itmVal is "missing value" then
							set emptyField to itm
							exit repeat
						end if
					end if
				end repeat

				if emptyField is not missing value then
					-- Click the empty shortcut field to ensure focus
					click emptyField
					delay 0.3
				end if

				-- Type the shortcut
				keystroke shortcut
				delay 0.5

				-- Tab to the replacement (With) column
				keystroke tab
				delay 0.5

				-- Type the replacement value
				keystroke newValue
				delay 0.5

				-- Press Escape then Tab to confirm without triggering re-sort issues
				-- Actually, use Return but with a longer delay after
				keystroke return
				delay 1.5

				log "Added " & shortcut & " → " & newValue
			end if
		end repeat

		-- Click Done to close the sheet
		delay 0.5
		click doneButton
		delay 1

		log "Sheet closed"
	end tell
end tell

-- Quit System Settings
delay 1
tell application "System Settings" to quit
delay 0.5

log "Complete: jgyst=" & yesterdayStr & ", jgdate=" & todayStr & ", jgtom=" & tomorrowStr
return "Success: jgyst=" & yesterdayStr & ", jgdate=" & todayStr & ", jgtom=" & tomorrowStr
