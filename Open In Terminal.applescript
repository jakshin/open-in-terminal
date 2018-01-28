(*
Open In Terminal v1.6 (macOS Sierra)

This is a Finder-toolbar script, which opens Terminal windows conveniently.
To build it as an application, run build.sh; Open In Terminal.app will be created.
To install the application, hold the Cmd key down and drag it into your Finder toolbar.

When its icon is clicked on in the toolbar of a Finder window, it opens a new Terminal window,
or tab if the fn key is down, and switches the shell's current working directory
to the Finder window's folder. You can also drag and drop folders onto its toolbar icon;
each dropped folder will be opened in a Terminal window, or tab if the fn key is down.

Copyright (c) 2009-2018 Jason Jackson

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
-- However this is set, press the fn key while clicking the icon in your Finder toolbar,
-- or while dragging and dropping icons onto it, to invert the behavior.
property useTabsByDefault : false

-- How to tell the shell to change its working directory, e.g. "cd", "pushd", or whatever else you like.
property changeDirectoryCommand : "cd"

-- How to tell the shell to clear its screen after changing its working directory,
-- e.g. "clear"; set to an empty string for no screen clearing.
property clearScreenCommand : ""

(*
Opens a Terminal window/tab in the frontmost Finder window's directory,
when the script's toolbar icon is clicked in Finder (or when it is launched directly).
*)
on run
	set openTab to my UseTabsThisTime()
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
					-- Sierra raises the error "No result was returned from some part of this expression"
					set currentFolder to (":Volumes" as alias) -- closest analogue for "this computer"
					
				else if systemErrorMessage contains "class cfol" and the front window's name is "Trash" then
					set currentFolder to (path to trash as alias)
					
				else
					if systemErrorMessage contains "class alia" then
						if currentName is "All My Files" then
							set errorMessage to "\"All My Files\" is a Spotlight search, not an on-disk folder, so it can't be opened in Terminal."
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
		display alert "No Folders to Open" as critical message "Only folders dropped on the icon can be opened in Terminal; you dropped some items on the icon, but none of them were folders."
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
	
	if modifierKeys contains "fn" then
		-- the fn key is down, invert the default setting
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
	
	set shellScript to my BuildShellScript(theFolder)
	set alreadyRunning to my TerminalIsRunning()
	
	tell application "Terminal"
		activate -- will open a window iff Terminal wasn't already running
		
		if alreadyRunning then
			if openTab then
				tell application "System Events" to tell process "Terminal" to keystroke "t" using {command down} -- new tab
				delay 1 -- so the new tab has time to open
				do script with command shellScript in front window
			else
				-- "do script" without "in front window" will open a new window
				do script with command shellScript
			end if
		else
			-- Terminal just started up, and opened a new window
			if shellScript is not "" then
				-- run the shell script in the front & only window
				do script with command shellScript in front window
			end if
		end if
	end tell
end OpenFolderInTerminal

(*
Builds a shell script which will change the working directory to the passed path (if applicable),
using the change-directory command configured above, and/or optionally clear the shell's screen, if so configured above.
theFolder should be passed as an alias.
*)
on BuildShellScript(theFolder)
	if theFolder is not "" then
		set shellScript to (changeDirectoryCommand & " " & quoted form of theFolder)
		if clearScreenCommand is not "" then set shellScript to shellScript & "; " & clearScreenCommand
	else if clearScreenCommand is not "" then
		set shellScript to clearScreenCommand
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

