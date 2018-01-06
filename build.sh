#!/bin/bash -e
# Builds the "Open In Terminal" Finder-toolbar script as an application.

script_name="Open In Terminal.applescript"
bundle_name="Open In Terminal.app"
bundle_id="com.apple.ScriptEditor.id.OpenInTerminal"
version="1.5"
copyright="Copyright © 2009-2018 Jason Jackson"

# --- Utilities ---

function absolute_path() {
	# prints a file's absolute path, given a relative path to it.
	# note that the file must exist.

	if [[ ! -f "$1" ]]; then
		return 1
	fi

	if [[ $1 == */* ]]; then
		echo "$(cd "${1%/*}"; pwd)/${1##*/}"
	else
		echo "$(pwd)/$1"
	fi
}

# --- Build Logic ---

# run from the path in which the build script resides
cd -- "`dirname "$0"`"

# remove any old version of the app bundle, and create a new one
rm -rf "$bundle_name"
osacompile -o "$bundle_name" "$script_name"

# fix up Info.plist
info_plist="$(absolute_path "$bundle_name/Contents/Info.plist")"

defaults write "$info_plist" CFBundleIdentifier "$bundle_id"
defaults write "$info_plist" CFBundleShortVersionString "$version"
defaults write "$info_plist" CFBundleVersion "$version"
defaults write "$info_plist" LSUIElement 1
defaults write "$info_plist" NSHumanReadableCopyright "$copyright"

plutil -convert xml1 "$info_plist"
chmod 644 "$info_plist"

# resources
cp icon/OpenInTerminal.icns "$bundle_name/Contents/Resources/droplet.icns"
cp modifier-keys/modifier-keys "$bundle_name/Contents/Resources"

# success!
echo Done
