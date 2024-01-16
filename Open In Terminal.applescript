(*
Open In Terminal v1.8.3

This is a Finder-toolbar script, which opens Terminal windows conveniently.
To build it as an application, run build.sh; Open In Terminal.app will be created.
To install the application, hold the Cmd key down and drag it into your Finder toolbar.

When its icon is clicked on in the toolbar of a Finder window, it opens a new Terminal window,
or tab if the fn or shift key is down, and switches the shell's current working directory
to the Finder window's folder. You can also drag and drop folders onto its toolbar icon;
each dropped folder will be opened in a Terminal window, or tab if the fn or shift key is down.

Copyright (c) 2009-2024 Jason Jackson

This program is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.
If not, see <http://www.gnu.org/licenses/>.
*)

-- Whether to open new tabs instead of new windows, by default (boolean).
-- Press the fn or shift key while clicking the icon in your Finder toolbar,
-- or while dragging and dropping icons onto it, to invert this setting.
property useTabsByDefault : false

-- How to tell the shell to change its working directory, e.g. "cd", "pushd", or whatever else you like.
-- Use a leading space to avoid having the command show up in your shell's history
-- (if you set HISTCONTROL=ignorespace on bash, or use "setopt hist_ignore_space" on zsh).
property changeDirectoryCommand : " cd"

-- How to tell the shell to clear its screen after changing its working directory,
-- e.g. "clear"; set to an empty string for no screen clearing.
property clearScreenCommand : "clear; printf '\\e[3J'"

-- Needed in order to receive command line parameters
use framework "Foundation"
use scripting additions

(*
Opens a Terminal window/tab in the frontmost Finder window's directory,
when the script's toolbar icon is clicked in Finder (or when it is launched directly).
*)
on run
	set openTab to my UseTabsThisTime()
	if openTab is missing value then return
	
	set args to (current application's NSProcessInfo's processInfo's arguments) as list
	if args's first item is "/usr/bin/osascript" then set args to rest of args
	set args to rest of args -- skip script/app name
	
	if (count of args) > 0 then
		set directoryStr to args's first item
		set options to rest of args
		my RunWithArgs(openTab, directoryStr, options)
		return
	end if
	
	set errorMessage to ""
	tell application "Finder"
		try
			-- this will raise an error if there isn't any frontmost Finder window,
			-- or it's not an ordinary file-browser window (e.g. preferences, information window, etc)
			set currentName to (the name of the front window)
			set currentFolder to (the target of the front window)
			
			try
				-- this will raise an error if the frontmost Finder window is showing a pseudo-folder
				set currentFolder to currentFolder as alias
				
			on error systemErrorMessage
				if systemErrorMessage contains "No result was returned" then
					-- the frontmost Finder window is showing this computer's pseudo-folder (the computer's name);
					-- macOS raises the error "No result was returned from some part of this expression"
					set currentFolder to (":Volumes" as alias) -- closest analogue for "this computer"
					
				else if systemErrorMessage contains "class cfol" and the front window's name is "Trash" then
					-- items shown by Finder in the Trash can come from various places (e.g. mounted drives, iCloud Drive),
					-- so we'll just use whatever macOS says is "the path to Trash" (always ~/.Trash as far as I can tell)
					set currentFolder to (path to trash as alias)
					
				else
					if systemErrorMessage contains "class alia" then
						if currentName is "Recents" then
							set errorMessage to "\"Recents\" is a Spotlight search, not an on-disk folder, so it can't be opened in Terminal."
						else
							set errorMessage to "Spotlight and tag searches aren't actually on-disk folders, so they can't be opened in Terminal."
						end if
						
					else if systemErrorMessage contains "class cdis" then
						set errorMessage to "\"All Tags\" isn't actually an on-disk folder, so it can't be opened in Terminal."
						
					else if systemErrorMessage contains "class cfol" then
						if currentName is "AirDrop" or currentName is "Network" then
							set errorMessage to "\"" & currentName & "\" isn't actually an on-disk folder, so it can't be opened in Terminal."
						else
							set errorMessage to "Network devices aren't actually on-disk folders, so they can't be opened in Terminal. " & Â
								"Open a folder shared by the device instead."
						end if
						
					else
						set errorMessage to "For some reason, this folder just can't be opened in Terminal. Sorry."
						set errorMessage to errorMessage & return & return & "macOS errored this error: " & systemErrorMessage
					end if
				end if
			end try
		on error systemErrorMessage number systemErrorNum
			if systemErrorMessage contains "Not authorized to send Apple events" then
				my DisplayTerminalError(openTab, systemErrorMessage, systemErrorNum)
				return
			end if
			
			-- apparently there is no frontmost Finder window (including minimized windows & windows in other spaces),
			-- or it's not an ordinary file-browser window; open a Terminal window/tab, but don't change its directory
			set currentFolder to ""
		end try
	end tell
	
	if errorMessage is not "" then
		display alert "Folder Can't Be Opened in Terminal" as critical message errorMessage
		return
	end if
	
	my OpenFolderInTerminal(currentFolder, openTab)
end run

(*
Opens a Terminal window/tab for each folder dropped onto the script's icon.
*)
on open droppedItems
	set openTabs to my UseTabsThisTime()
	set folderWasDropped to false
	
	repeat with droppedItem in droppedItems
		set droppedItem to droppedItem as alias
		
		if my ItemIsAFolder(droppedItem) then
			set folderWasDropped to true
			if not OpenFolderInTerminal(droppedItem, openTabs) then return
		end if
	end repeat
	
	if folderWasDropped is false then
		if (count of droppedItems) is 1 then
			display alert "That's not a folder" as critical message "Only folders dropped on the icon can be opened in Terminal."
		else
			display alert "Those aren't folders" as critical message "Only folders dropped on the icon can be opened in Terminal. " & Â
				"Everything you dropped was a file, not a folder."
		end if
	end if
end open

(*
Finds out which modifier keys are currently down, and uses that information,
plus the useTabsByDefault property, to decide whether to use tabs this time.
*)
on UseTabsThisTime()
	set pathToMe to POSIX path of (path to me)
	
	if pathToMe ends with ".app/" then
		set checkModifierKeysPath to pathToMe & "Contents/Resources/modifier-keys"
	else
		-- assume we're running in Script Editor
		set pathToMyFolder to characters 1 thru -((offset of "/" in (reverse of items of pathToMe as string))) of pathToMe as string
		set checkModifierKeysPath to pathToMyFolder & "modifier-keys/modifier-keys"
	end if
	
	set modifierKeys to do shell script quoted form of checkModifierKeysPath
	
	if modifierKeys contains "option" then
		-- the option key is down, and the Finder window will close
		return missing value
		
	else if modifierKeys contains "fn" or modifierKeys contains "shift" then
		-- the fn or shift key is down, invert the default setting
		set useTabs to not useTabsByDefault
	else
		-- use the default setting
		set useTabs to useTabsByDefault
	end if
	
	return useTabs
end UseTabsThisTime

(*
Run using the command-line arguments instead of a Finder window.
This is rudimentary, a bit weird, and doesn't have any error checking/reporting,
because it's meant only to enable the accompanying "term" shell script,
and this app's use in Context Menu (https://langui.net/context-menu).
*)
on RunWithArgs(openTab, directoryStr, options)
	set optionsStarted to false
	
	repeat with opt in options
		set opt to opt as string
		
		-- Context Menu passes all selected directories (or the current directory) as arguments,
		-- so to distinguish a real option from a directory named like an option (e.g. "--window"),
		-- we require an empty argument to signal that option arguments have started
		if opt is "" then set optionsStarted to true
		
		if optionsStarted then
			if opt is "-t" or opt is "--tab" then
				set openTab to true
			else if opt is "-w" or opt is "--window" then
				set openTab to false
			end if
		end if
	end repeat
	
	if directoryStr is not "" then
		set directory to directoryStr as POSIX file
		set dirAlias to directory as alias
		if ItemIsAFolder(dirAlias) then my OpenFolderInTerminal(dirAlias, openTab)
	end if
end RunWithArgs

(*
Determines whether or not an item is a folder.
theItem should be passed as an alias.
*)
on ItemIsAFolder(theItem)
	tell application "Finder"
		if theItem's POSIX path ends with "/" then
			return true
		else
			return false
		end if
	end tell
end ItemIsAFolder

(*
Opens a Terminal window/tab, and changes the shell's working directory to the passed folder (if applicable;
if theFolder is an empty string, the window/tab will be opened but no cd command issued to it).

theFolder = The folder to cd to; should be passed as an alias, and must be a folder, not a regular file.
openTab = Open a tab instead of a window, if a window is already open? (boolean)
*)
on OpenFolderInTerminal(theFolder, openTab)
	if theFolder is not "" then
		set theFolder to POSIX path of theFolder
	end if
	
	try
		set alreadyRunning to my TerminalIsRunning()
		set hasShellWindows to my TerminalHasShellWindows() -- call here so we know right away if we don't have automation permission for Terminal
		
		if not openTab or not alreadyRunning or not hasShellWindows then
			considering numeric strings
				set versionString to system version of (system info)
				set bigSurOrLater to versionString ³ "11"
			end considering
			
			if theFolder is "" then
				-- if there are open Terminal windows, but they're all in other spaces, this brings one of them to the front,
				-- but doesn't necessarily switch spaces to make it visible, depending on Mission Control settings;
				-- oh well, it won't come up during intended use (clicking an icon in a Finder window's toolbar)
				do shell script "open -a Terminal"
				
			else if bigSurOrLater and alreadyRunning and TerminalHasAnyWindowsInThisSpace() then
				-- using "open -a Terminal path" brings an extra Terminal window to the front on Big Sur,
				-- so we use this clunkier approach as a workaround
				my OpenTerminalWindow()
				my SendShellScript(theFolder)
			else
				-- life is simpler on Catalina: this always opens a new Terminal window,
				-- with its shell's working directory set to the passed folder, no scripting needed
				-- (we also take this code path on Big Sur when Terminal isn't running, or has no open shell windows)
				do shell script "open -a Terminal " & quoted form of theFolder
			end if
		else
			-- we want a new tab; Terminal is already running, and has a window (though maybe not in this space)
			
			-- this brings just one Terminal window to the front (but buggily bringing an extra window to the front on Big Sur, ugh),
			-- opening a new window if there isn't one in any space, unminimized and unhiding if it needs to; like "activate",
			-- it only switches spaces if System Preferences > Mission Control > "When switching to an application ..." is checked
			do shell script "open -a Terminal"
			delay 0.5
			
			-- open a new tab (or a new window, if there's not already one in this space)
			my OpenTerminalTab()
			my SendShellScript(theFolder)
		end if
		
	on error systemErrorMessage number systemErrorNum
		my DisplayTerminalError(openTab, systemErrorMessage, systemErrorNum)
		return false
	end try
	
	return true
end OpenFolderInTerminal

(*
Sends Terminal a shell script which changes the front window's working directory to the passed path.
theFolder should be passed as an alias.
*)
on SendShellScript(theFolder)
	if theFolder is not "" then
		set shellScript to (changeDirectoryCommand & " " & quoted form of theFolder)
		if clearScreenCommand is not "" then set shellScript to shellScript & "; " & clearScreenCommand
		tell application "Terminal" to do script with command shellScript in front window
	end if
end SendShellScript

(*
Determines whether or not the Terminal application is already running.
*)
on TerminalIsRunning()
	tell application "System Events"
		set alreadyRunning to (name of processes) contains "Terminal"
	end tell
	
	return alreadyRunning
end TerminalIsRunning

(*
Reports whether Terminal has open shell windows.
Includes shell windows in any space, even if they're minimized or hidden;
excludes non-shell windows like preferences, "New Command" and "New Remote Connection".
*)
on TerminalHasShellWindows()
	tell application "Terminal"
		-- Terminal includes "New Command" and "New Remote Connection" once they've been opened,
		-- even if they were later closed, so we filter them out below
		set windowCount to count of windows
		
		if windowCount is greater than 0 then
			repeat with win in windows
				try
					-- an error is raised when trying to get a non-shell window's selected tab
					set selectedTab to win's selected tab
					return true
				on error
					-- ignore it
				end try
			end repeat
		end if
	end tell
	
	return false
end TerminalHasShellWindows

(*
Reports whether Terminal has any open windows in this space.
Includes any kind of window, not just shell windows.
Includes windows minimized from any space, and hidden windows.
*)
on TerminalHasAnyWindowsInThisSpace()
	tell application "System Events"
		tell process "Terminal"
			set windowCount to count of windows
			return windowCount > 0
		end tell
	end tell
end TerminalHasAnyWindowsInThisSpace

(*
Opens a new tab in Terminal's frontmost window, or a new Terminal window if there isn't yet one in this space.
Terminal must already be running, or this will error out.
*)
on OpenTerminalTab()
	tell application "System Events"
		-- we used to use a keystroke to open the tab, but that doesn't work if the shift key is down,
		-- like if you shift+click on the app's icon and hold shift down just a bit too long:
		-- // tell application "System Events" to tell process "Terminal" to keystroke "t" using {command down}
		
		set terminal to application process "Terminal"
		
		-- normally setting frontmost is needed for the click below to work right (otherwise it opens a new window,
		-- instead of a new tab as intended), but we don't want to bring all Terminal windows forward,
		-- so we call "open -a Terminal" before calling this function, instead:
		-- // set frontmost of terminal to true
		
		click menu item 1 of Â
			first menu of menu item "New Tab" of Â
			first menu of menu bar item "Shell" of Â
			first menu bar of terminal
		
		delay 0.5 -- give the tab some time to open
	end tell
end OpenTerminalTab

(*
Opens a new Terminal window, and brings just it to the front. Used on Big Sur,
where an Apple bug makes "open -a Terminal path" bring an annoying extra window to the front.
Terminal must already be running, or this will error out.
*)
on OpenTerminalWindow()
	tell application "System Events"
		set terminal to application process "Terminal"
		
		click menu item 1 of Â
			first menu of menu item "New Window" of Â
			first menu of menu bar item "Shell" of Â
			first menu bar of terminal
		
		delay 0.5 -- give the window some time to open
	end tell
end OpenTerminalWindow

(*
Displays an error message in an alert when we fail to open a Terminal window/tab.
Adds some error-specific explanatory text when possible.
*)
on DisplayTerminalError(openingTab, systemErrorMessage, systemErrorNum)
	considering numeric strings
		set versionString to system version of (system info)
		set venturaOrLater to versionString ³ "13"
	end considering
	
	if openingTab then
		set title to "Unable to open a new Terminal tab"
	else
		set title to "Unable to open a new Terminal window"
	end if
	
	set errorMessage to "An error occurred: " & systemErrorMessage & " (" & systemErrorNum & ")"
	
	if errorMessage contains "not allowed assistive access" then
		if venturaOrLater then
			set errorMessage to errorMessage & return & return & Â
				"To fix this problem, open System Settings and navigate to Privacy & Security > Accessibility. " & Â
				"Find Open In Terminal in the list, and turn its toggle switch on." & return & return & Â
				"If its toggle switch is already on, remove Open In Terminal from the list, then add it again."
		else
			set errorMessage to errorMessage & return & return & Â
				"To fix this problem, open System Preferences and navigate to Security & Privacy > Privacy tab > Accessibility. " & Â
				"Find Open In Terminal in the list, and check its checkbox." & return & return & Â
				"If its checkbox is already checked, remove Open In Terminal from the list, then add it again."
		end if
		
	else if errorMessage contains "Not authorized to send Apple events to" then
		set eventsTo to "events to"
		set pos to (offset of eventsTo in systemErrorMessage) + ((eventsTo's length) + 1)
		set appName to systemErrorMessage's text pos thru ((systemErrorMessage's length) - 1)
		
		if venturaOrLater then
			set errorMessage to errorMessage & return & return & Â
				"To fix this problem, open System Settings and navigate to Privacy & Security > Automation. " & Â
				"Find Open In Terminal in the list, and turn on its toggle switch for \"" & appName & "\"."
		else
			set errorMessage to errorMessage & return & return & Â
				"To fix this problem, open System Preferences and navigate to Security & Privacy > Privacy tab > Automation. " & Â
				"Find Open In Terminal in the list, and check its checkbox for \"" & appName & "\"."
		end if
	end if
	
	display alert title as critical message errorMessage
end DisplayTerminalError
