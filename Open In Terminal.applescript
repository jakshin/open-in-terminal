(*
OpenInTerminal v1.3
Copyright (c) 2009-2010 Jason Jackson

This program is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.
If not, see <http://www.gnu.org/licenses/>.
*)

-- Whether to open new tabs instead of new windows, when possible.
property useTabsByDefault : false

-- Whether to try to reuse existing windows/tabs, if they're not busy.
property useExistingByDefault : false

-- How to tell the shell to change its working directory; e.g. "cd", "pushd", or whatever else you like.
property changeDirectoryCommand : "cd"

-- How to tell the shell to clear its screen; e.g. "clear"; use the empty string for no screen clearing.
property clearScreenCommand : ""

-- Whether to always try to open the "canonical" version of a Finder path,
-- e.g. "/Volumes/Stash" if Finder reports the window's current path as "/Volumes/Stash-1" and "/Volumes/Stash" exists.
property useCanonicalPath : false


(*
Opens a Terminal window/tab in the frontmost Finder window's directory,
when the script's toolbar icon is clicked in Finder, or when it is launched directly by the user.
*)
on run
	tell application "Finder"
		try
			-- this will fail if there isn't any frontmost Finder window
			set currentFolder to (the target of the front window)
			
			try
				-- this will fail if the frontmost Finder window is for the trash, network, or a Spotlight search
				set currentFolder to currentFolder as alias
				
			on error errorMessage
				if errorMessage contains "class pcmp" then
					set currentFolder to (":Volumes" as alias) -- closest analogue for "this computer"
					
				else if errorMessage contains "class cfol" and the front window's name is "Trash" then
					set currentFolder to (path to trash as alias)
					
				else
					if errorMessage contains "class alia" then
						set details to "Spotlight searches aren't actually on-disk folders, so they can't be opened in Terminal."
						set buttonText to "Bummer"
					else if errorMessage contains "class cfol" then
						set details to "The network folder and its immediate subfolders aren't actually on-disk folders, so they can't be opened in Terminal."
						set buttonText to "Bummer"
					else
						set details to "For some unknown reason, this folder just can't be opened in Terminal. Could be a bug. Sorry."
						set buttonText to "That Sucks"
					end if
					
					try
						activate
						display alert "Folder can't be opened in Terminal" as warning message details buttons {buttonText} default button 1 cancel button 1 giving up after 120
						return
					on error
						-- we catch errors and return here so that escape can be used to close the alert dialog
						return
					end try
				end if
			end try
		on error
			-- there is no frontmost Finder window (including minimized windows & windows in other spaces);
			-- open a Terminal window, but don't change its directory
			set currentFolder to ""
		end try
	end tell
	
	my OpenFolderInTerminal(currentFolder)
end run

(*
Opens a Terminal window/tab for each folder dropped onto the icon.
*)
on open droppedItems
	set folderWasDropped to false
	
	repeat with droppedItem in droppedItems
		set droppedItem to droppedItem as alias
		
		if my ItemIsAFolder(droppedItem) then
			my OpenFolderInTerminal(droppedItem)
			set folderWasDropped to true
		end if
	end repeat
	
	if folderWasDropped is false then
		try
			activate
			display alert "No folders to open" as warning message "Only folders dropped on the icon will be opened in Terminal; you dropped some items on the icon, but none of them were folders." buttons "Okay" default button 1 cancel button 1 giving up after 120
			return
		on error
			-- we catch errors and return here so that escape can be used to close the error dialog, by cancelling it
			return
		end try
	end if
end open

(*
Determines whether or not an item is a folder.
theItem should be passed as an alias.
*)
on ItemIsAFolder(theItem)
	tell application "Finder"
		if theItem's POSIX path ends with "/" then return true
		return false
	end tell
end ItemIsAFolder

(*
Opens a Terminal window or tab (based on the properties configured above),
and changes the shell's working directory to the passed folder (if applicable).
theFolder should be passed as an alias, and MUST be a folder, not a regular file.
*)
on OpenFolderInTerminal(theFolder)
	if theFolder is not "" then
		set theFolder to POSIX path of theFolder
		
		-- if canonical paths were requested and this isn't one, deal with that
		if useCanonicalPath then
			set theFolderName to (theFolder as string)
			
			if theFolderName's length > 1 then
				set secondLastCharacter to character ((theFolderName's length) - 1) of theFolderName
				set thirdLastCharacter to character ((theFolderName's length) - 2) of theFolderName
				
				if thirdLastCharacter is "-" and my CharacterIsADigit(secondLastCharacter) then
					set theFolderName to (get characters 1 thru ((theFolderName's length) - 3) of theFolderName as string)
					set theFolder to (POSIX path of theFolderName as text) & "/"
				end if
			end if
		end if
	end if
	
	set alreadyRunning to my LaunchTerminal()
	
	if not alreadyRunning then
		set useExisting to true
	else
		set useExisting to useExistingByDefault
	end if
	
	set useTabs to useTabsByDefault
	
	tell application "Terminal"
		activate
		set shellScript to my BuildShellScript(theFolder)
		
		if (count of windows) is 0 then
			if shellScript is not "" then
				-- this will open a new window as a side effect
				do script with command shellScript
			else
				my OpenNewTerminalWindow()
			end if
		else
			-- we need to open a new window/tab, unless we want to reuse existing ones and can do so
			set openNew to true
			
			if useExisting then
				-- try to find a tab in a window which isn't busy, so we can reuse it
				set foundExisting to false
				set windowNum to 1 -- windows are numbered from front to back
				
				repeat while windowNum ² (count of windows)
					-- tabs are numbered in the order opened, so check the selected tab first
					if window windowNum's selected tab is not busy then
						set window windowNum's frontmost to true -- (sets the window's number to 1)
						
						set openNew to false
						set foundExisting to true
					else
						set tabNum to 1
						
						repeat while tabNum ² ((count of tabs) of window windowNum)
							if window windowNum's tab tabNum is not busy then
								set window windowNum's tab tabNum's selected to true
								set window windowNum's frontmost to true -- (sets the window's number to 1)
								
								set openNew to false
								set foundExisting to true
								exit repeat
							end if
							
							set tabNum to tabNum + 1
						end repeat
					end if
					
					if foundExisting then exit repeat
					set windowNum to windowNum + 1
				end repeat
			end if
			
			if openNew then
				if useTabs then
					my OpenNewTerminalTab()
				else
					my OpenNewTerminalWindow()
				end if
			end if
			
			-- regardless of whether we just made an existing window/tab frontmost, or opened a new one,
			-- send any applicable shell script to it
			if shellScript is not "" then do script with command shellScript in window 1
		end if
	end tell
end OpenFolderInTerminal

(*
Determines whether or not a given character is a digit, returning true or false.
*)
on CharacterIsADigit(theCharacter)
	try
		set theDigit to (theCharacter as number)
		return true
	on error
		return false
	end try
end CharacterIsADigit

(*
Builds a shell script which will change the working directory to the passed path (if applicable),
using the change-directory command configured above, and optionally also clear the shell's screen, if so configured above.
theFolder should be passed as an alias.
*)
on BuildShellScript(theFolder)
	if theFolder is not "" then
		set shellScript to (changeDirectoryCommand & " " & quoted form of theFolder)
		if clearScreenCommand is not "" then set shellScript to shellScript & " ; " & clearScreenCommand
	else if clearScreenCommand is not "" then
		set shellScript to clearScreenCommand
	else
		set shellScript to ""
	end if
	
	return shellScript
end BuildShellScript

(*
Opens a new Terminal window.
*)
on OpenNewTerminalWindow()
	tell application "System Events" to tell process "Terminal" to keystroke "n" using command down
end OpenNewTerminalWindow

(*
Opens a new Terminal tab, in its frontmost window.
*)
on OpenNewTerminalTab()
	tell application "System Events" to tell process "Terminal" to keystroke "t" using command down
end OpenNewTerminalTab

(*
Launches the Terminal application if needed, waiting until it's completed launching to return;
if Terminal is already running, this returns immediately.
*)
on LaunchTerminal()
	tell application "System Events"
		set alreadyRunning to (name of processes) contains "Terminal"
	end tell
	
	if not alreadyRunning then
		launch application "Terminal"
		
		tell application "Terminal"
			repeat while (count of windows) is 0
				delay 0.1
			end repeat
		end tell
	end if
	
	return alreadyRunning
end LaunchTerminal
