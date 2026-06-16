-- claude-auto-ping.applescript
--
-- Opens the Claude desktop app, starts a new chat, pastes a message via the
-- clipboard, and optionally presses Return to send it. The message is passed as
-- an argument and delivered through the clipboard, never interpolated into the
-- script body, so Unicode and Bangla text are preserved safely.
--
-- Usage:
--   osascript claude-auto-ping.applescript "MESSAGE" "APP_NAME" "return|noreturn"
--
-- Defaults: MESSAGE="hi", APP_NAME="Claude", mode="return".

on run argv
	set theMessage to "hi"
	set appName to "Claude"
	set pressReturn to true

	if (count of argv) ≥ 1 then set theMessage to item 1 of argv
	if (count of argv) ≥ 2 then set appName to item 2 of argv
	if (count of argv) ≥ 3 then
		if item 3 of argv is "noreturn" then set pressReturn to false
	end if

	-- Preserve the user's current clipboard so it can be restored afterward.
	set savedClipboard to missing value
	try
		set savedClipboard to the clipboard
	end try

	try
		-- Launch and foreground Claude.
		tell application appName to activate
		delay 2.0

		tell application "System Events"
			-- Open a new conversation.
			keystroke "n" using {command down}
			delay 1.5
		end tell

		-- Put the message on the clipboard and paste it.
		set the clipboard to theMessage
		delay 0.3
		tell application "System Events"
			keystroke "v" using {command down}
			delay 0.8
			if pressReturn then
				key code 36
			end if
		end tell
	on error errorMessage number errorNumber
		-- Restore the clipboard even when something fails.
		if savedClipboard is not missing value then
			set the clipboard to savedClipboard
		end if
		error "claude-auto-ping failed: " & errorMessage & " (" & errorNumber & ")"
	end try

	-- Restore the previous clipboard.
	delay 0.3
	if savedClipboard is not missing value then
		set the clipboard to savedClipboard
	end if

	return "ok"
end run
