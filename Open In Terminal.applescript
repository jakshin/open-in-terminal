(*
Open In Terminal v1.7.3

This is a Finder-toolbar script, which opens Terminal windows conveniently.
To build it as an application, run build.sh; Open In Terminal.app will be created.
To install the application, hold the Cmd key down and drag it into your Finder toolbar.

When its icon is clicked on in the toolbar of a Finder window, it opens a new Terminal window,
or tab if the fn or shift key is down, and switches the shell's current working directory
to the Finder window's folder. You can also drag and drop folders onto its toolbar icon;
each dropped folder will be opened in a Terminal window, or tab if the fn or shift key is down.

Copyright (c) 2009-2021 Jason Jackson

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

(*
Opens a Terminal window/tab in the frontmost Finder window's directory,
when the script's toolbar icon is clicked in Finder (or when it is launched directly).
*)
on run
	set openTab to my UseTabsThisTime()
	if openTab is missing value then return
	
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
							set errorMessage to "Network devices aren't actually on-disk folders, so they can't be opened in Terminal. Open a folder shared by the device instead."
						end if
						
					else
						set errorMessage to "For some reason, this folder just can't be opened in Terminal. Sorry."
						set errorMessage to errorMessage & return & return & "macOS errored this error: " & systemErrorMessage
					end if
				end if
			end try
		on error
			-- there is no frontmost Finder window (including minimized windows & windows in other spaces),
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
			my OpenFolderInTerminal(droppedItem, openTabs)
			set folderWasDropped to true
		end if
	end repeat
	
	if folderWasDropped is false then
		if (count of droppedItems) is 1 then
			display alert "That's not a folder" as critical message "Only folders dropped on the icon can be opened in Terminal."
		else
			display alert "Those aren't folders" as critical message "Only folders dropped on the icon can be opened in Terminal. Everything you dropped was a file, not a folder."
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
	
	set alreadyRunning to my TerminalIsRunning()
	if alreadyRunning then
		set windowCount to my CountTerminalWindows()
	end if
	
	if not openTab or not alreadyRunning or windowCount is 0 then
		if theFolder is not "" then
			-- this always opens a new Terminal window;
			-- its shell's CWD is set to the folder, no scripting needed
			do shell script "open -a Terminal " & quoted form of theFolder
		else
			-- if there are open Terminal windows, but they're all in other spaces,
			-- this will bring one of those windows to the front, but not switch spaces... oh well,
			-- it won't come up during indended use (clicking an icon in a Finder window's toolbar)
			do shell script "open -a Terminal"
		end if
	else
		-- we want a new tab; Terminal is already running, and has a window (though maybe not in this space)
		
		-- this brings just one window to the front, opening a new window if there isn't one (in any space),
		-- unminimized and unhiding if it needs to; like "activate", it DOESN'T switch spaces
		do shell script "open -a Terminal"
		delay 0.5
		
		OpenTerminalTab()  -- open a new tab (or a new window, if there's not already one in this space)
		delay 0.5 -- so the new tab has time to open
		
		set shellScript to my BuildShellScript(theFolder)
		if shellScript is not "" then
			tell application "Terminal"
				do script with command shellScript in front window
			end tell
		end if
	end if
end OpenFolderInTerminal

(*
Builds a shell script which will change the working directory to the passed path (if applicable),
using the change-directory command configured above, and optionally clear the shell's screen.
theFolder should be passed as an alias.
*)
on BuildShellScript(theFolder)
	if theFolder is not "" then
		set shellScript to (changeDirectoryCommand & " " & quoted form of theFolder)
		if clearScreenCommand is not "" then set shellScript to shellScript & "; " & clearScreenCommand
	else
		set shellScript to ""
	end if
	
	return shellScript
end BuildShellScript

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
Counts open Terminal windows, or really tabs because that's how Terminal counts windows,
which is fine for our purposes here, because we only care whether there are zero or not.
Includes minimized and hidden windows, in any space, but excludes non-shell windows
like preferences, "New Command" and "New Remote Connection".
*)
on CountTerminalWindows()
	tell application "Terminal"
		-- Terminal includes "New Command" and "New Remote Connection" once they've been opened,
		-- even if they were later closed, so we filter them out below
		set windowCount to count of windows
		
		if windowCount is greater than 0 then
			repeat with win in windows
				try
					-- an error is raised when trying to get a non-shell window's selected tab
					set selectedTab to win's selected tab
				on error
					set windowCount to windowCount - 1
				end try
			end repeat
		end if
	end tell
	
	return windowCount
end CountTerminalWindows

(*
Opens a new tab in Terminal's frontmost window, or a new Terminal window
if there isn't already one open in this space.
*)
on OpenTerminalTab()
	tell application "System Events"
		-- we used to use a keystroke to open the tab, but that doesn't work if the shift key is down,
		-- like if you shift+click on the app's icon and hold shift down just a bit too long
		-- tell application "System Events" to tell process "Terminal" to keystroke "t" using {command down}
		
		set terminal to application process "Terminal"
		
		-- normally this is needed for the click below to work right (otherwise it opens a new window,
		-- instead of a new tab as intended), but we don't want to bring all Terminal windows forward,
		-- so we call "open -a Terminal" before calling this function, instead
		-- set frontmost of terminal to true
		
		click menu item 1 of Â
			first menu of menu item "New Tab" of Â
			first menu of menu bar item "Shell" of Â
			first menu bar of terminal
	end tell
end OpenTerminalTab
