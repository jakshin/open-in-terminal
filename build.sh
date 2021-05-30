#!/bin/bash -e
# Builds the "Open In Terminal" Finder-toolbar script as an application.

script_name="Open In Terminal.applescript"
bundle_name="Open In Terminal.app"
bundle_id="com.apple.ScriptEditor.id.OpenInTerminal"

function usage() {
	script_name="`basename "$0"`"
	echo 'Builds the "Open In Terminal" Finder-toolbar script as an application.'
	echo 'See README.md for installation instructions.'
	echo
	echo "Usage: $script_name [options]"
	echo
	echo "By default, a light or dark icon is chosen automatically, based on"
	echo "macOS's current setting. Pass --light or --dark to override."
	exit 1
}

unset dark

for arg in "$@"; do
	if [[ $arg == "--dark" ]]; then
		dark=true
	elif [[ $arg == "--light" ]]; then
		dark=false
	else  # anything else, including -h/--help
		usage
	fi
done

if [[ -z $dark ]]; then
	dark="$(osascript -e 'tell application "System Events" to tell appearance preferences to log dark mode is true' 2>&1)"
fi

[[ $dark == true ]] && icon="macOS-10-dark" || icon="macOS-10-light"


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
cd -- "$(dirname "$0")"

# find some info in the script
version="$(head -n 5 "$script_name" | grep -Eo "[0-9.]{3,}")"
copyright="$(head -n 20 "Open In Terminal.applescript" | grep -E "^Copyright")"

if [[ -z $version || -z $copyright ]]; then
	echo "Unable to determine bundle version and/or copyright, aborting"
	exit 1
fi

# remove any existing version of the app bundle, and create a new one
rm -rf "$bundle_name"
osacompile -o "$bundle_name" "$script_name"
echo "Built $bundle_name"

# copy resources into the bundle
cp "icon/$icon.icns" "$bundle_name/Contents/Resources/droplet.icns"
cp modifier-keys/modifier-keys "$bundle_name/Contents/Resources"

# fix up Info.plist
info_plist="$(absolute_path "$bundle_name/Contents/Info.plist")"

defaults write "$info_plist" CFBundleIdentifier "$bundle_id"
defaults write "$info_plist" CFBundleShortVersionString "$version"
defaults write "$info_plist" CFBundleVersion "$version"
defaults write "$info_plist" LSUIElement 1
defaults write "$info_plist" NSHumanReadableCopyright "'$copyright'"

plutil -convert xml1 "$info_plist"
chmod 644 "$info_plist"

# success!
echo Done
