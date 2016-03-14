(*
Open In Terminal v1.4 (Mavericks)

This is a Finder-toolbar script, which opens Terminal windows conveniently.
To build it as an application, run build.sh; Open In Terminal.app will be created.
To install the application, hold the Cmd key down and drag it into your Finder toolbar.

When its icon is clicked on in the toolbar of a Finder window, it opens a new Terminal window,
or tab if the fn key is down, and switches the shell's current working directory
to the Finder window's folder. You can also drag and drop folders onto its toolbar icon;
each dropped folder will be opened in a Terminal window, or tab if the fn key is down.

Copyright (c) 2009-2014 Jason Jackson

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
	set errorIsUnexpected to false
	
	tell application "Finder"
		try
			-- this will raise an error if there isn't any frontmost Finder window,
			-- or it's not an ordinary file-browser window (e.g. preferences, information window, etc)
			set currentFolder to (the target of the front window)
			
			try
				-- this will raise an error if the frontmost Finder window is showing this computer's pseudo-folder,
				-- the Trash, the Network pseudo-folder, or a Spotlight search
				set currentFolder to currentFolder as alias
				
			on error systemErrorMessage
				if systemErrorMessage contains "No result was returned" or systemErrorMessage contains "class pcmp" then
					-- the frontmost Finder window is showing this computer's pseudo-folder (the computer's name);
					-- Mavericks raises the error "No result was returned from some part of this expression",
					-- and Snow Leopard raises an error containing "class pcmp"; hopefully Lion & Mountain Lion
					-- each do one of those two things too, but I don't know for sure
					set currentFolder to (":Volumes" as alias) -- closest analogue for "this computer"
					
				else if systemErrorMessage contains "class cfol" and the front window's name is "Trash" then
					set currentFolder to (path to trash as alias)
					
				else
					if systemErrorMessage contains "class alia" then
						set errorMessage to "Spotlight searches aren't actually on-disk folders, so they can't be opened in Terminal."
						
					else if systemErrorMessage contains "class cfol" then
						set errorMessage to "The Network folder and its immediate subfolders aren't actually on-disk folders, so they can't be opened in Terminal."
						
					else
						set errorMessage to "For some unknown reason, this folder just can't be opened in Terminal. Sorry."
						set errorIsUnexpected to true
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
	set checkModifierKeysPath to POSIX path of (path to me) & "Contents/Resources/modifier-keys"
	set modifierKeys to do shell script "\"" & checkModifierKeysPath & "\""
	
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
	set wasAlreadyRunning to my LaunchTerminal()
	
	tell application "Terminal"
		activate
		
		if (count of windows) is 0 then
			if shellScript is not "" then
				-- this will open a new window as a side effect
				do script with command shellScript
			else
				-- no shell script to run, just open a window
				my OpenNewTerminalWindow()
			end if
		else
			-- open a new window/tab, unless Terminal just started up (in which case it just opened a window itself)
			if wasAlreadyRunning then
				if openTab then
					my OpenNewTerminalTab()
				else
					my OpenNewTerminalWindow()
				end if
				
				-- delay briefly, in case new windows/tabs open with "same working directory",
				-- so that our cd command will be sent after Terminal's own
				delay 0.2
			end if
			
			-- send any applicable shell script to it
			if shellScript is not "" then do script with command shellScript in front window
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
Returns a variable indicating whether Terminal was already running.
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
