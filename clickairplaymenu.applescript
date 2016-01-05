on run argv
	set tvname to item 1 of argv
	display notification "Sending display to " & tvname with title "Grabbing TV"
	tell application "System Events"
		tell process "SystemUIServer"
			click (menu bar item 1 of menu bar 1 whose description contains "Displays")
			set displaymenu to menu 1 of result
			-- Tolerate numbers in brackets after the tv name --
			click ((menu item 1 where its name starts with tvname) of displaymenu)
		end tell
	end tell
end run

