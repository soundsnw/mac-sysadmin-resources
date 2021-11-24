#!/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

########################################################################################################
#
# Jamf Self Service Script to check user's OneDrive folder for illegal
# characters, leading or trailing spaces and corrects them to 
# allow smooth synchronization.
#
# Modified by soundsnw, January 26, 2020
#
# Important: The OneDrive folder name used in your organization 
# needs to be specified in the script (line 171)
#
# If you want a slightly faster script, at the cost of not making a backup,
# comment out or delete line 221-228 and edit the Jamf notifications at the end.
#
# Changelog
# January 26, 2020
# - Fixed numerical conditionals in while loops and file number comparisons, corrected quoting.
#
# September 8, 2019
# - Treats directories first
# - If the corrected filename is used by another file, appends a number at the end to 
#   avoid overwriting
# - Checks if the number of files before and after renaming is the same
# - Uses mktemp for temp files
# - Restarts OneDrive and cleans up temp files if aborted
# - Uses local and readonly variables where appropriate
#
# September 4, 2019
# - Changed backup parent directory to user folder to avoid potential problems
#   if Desktop sync is turned on
#
# September 3, 2019
# - The script is now much faster, while still logging and making a backup before changing filenames
# - Backup being made using APFS clonefile (support for HFS dropped)
# - Spotlight prevented from indexing backup to prevent users from opening the wrong file later
#
# September 2, 2019
# - Only does rename operations on relevant files, for increased speed and safety
# - No longer fixes # or %, which are supported in more recent versions of OneDrive
#   https://support.office.com/en-us/article/invalid-file-names-and-file-types-in-onedrive-onedrive-for-business-and-sharepoint-64883a5d-228e-48f5-b3d2-eb39e07630fa#invalidcharacters
# - Changed all exit status codes to 0, to keep things looking tidy in Self Service
# - No longer removes .fstemp files before doing rename operations
#
# Version: 0.6
#
# Original script by dsavage:
# https://github.com/UoE-macOS/jss/blob/master/utilities-fix-file-names.sh
#
# Use of this script is entirely at your own risk, there is no warranty.
#
########################################################################################################

set -o pipefail

unset fixchars fixtrail fixlead

# Cleanup function, removes temp files and restarts OneDrive

function finish() {

	[[ -z "$fixchars" ]] || rm -f "$fixchars"
	[[ -z "$fixtrail" ]] || rm -f "$fixtrail"
	[[ -z "$fixlead" ]] || rm -f "$fixlead"

	[[ $(pgrep "OneDrive") ]] || open -gj "/Applications/OneDrive.app"

	[[ ! $(pgrep "caffeinate") ]] || killall "caffeinate"

	exit 0

}
trap finish HUP INT QUIT TERM

# Make sure the machine does not sleep until the script is finished

(caffeinate -sim -t 3600) &
disown

# Filename correction functions

fix_trailing_chars() {

	local linecount counter line name path fixedname
	linecount="$(wc -l "$fixtrail" | awk '{print $1}')"
	counter="$linecount"

	while ! [ "$counter" -eq 0 ]; do

		line="$(sed -n "${counter}"p "$fixtrail")"
		name="$(basename "$line")"
		path="$(dirname "$line")"
		fixedname="$(echo "$name" | awk '{sub(/[ \t]+$/, "")};1')"

		if [[ -f "$path"'/'"$fixedname" ]] || [[ -d "$path"'/'"$fixedname" ]]; then

			mv -vf "$line" "$path"'/'"$fixedname"'-'"$(jot -nr 1 100000 999999)" >>"$fixlog"

		else

			mv -vf "$line" "$path"'/'"$fixedname" >>"$fixlog"

		fi

		((counter = counter - 1))
	done
}

fix_leading_spaces() {

	local linecount counter line name path fixedname
	linecount="$(wc -l "$fixlead" | awk '{print $1}')"
	counter="$linecount"
	while ! [ "$counter" -eq 0 ]; do

		line="$(sed -n "${counter}"p "$fixlead")"
		name="$(basename "$line")"
		path="$(dirname "$line")"
		fixedname="$(echo "$name" | sed -e 's/^[ \t]*//')"

		if [[ -f "$path"'/'"$fixedname" ]] || [[ -d "$path"'/'"$fixedname" ]]; then

			mv -vf "$line" "$path"'/'"$fixedname"'-'"$(jot -nr 1 100000 999999)" >>"$fixlog"

		else

			mv -vf "$line" "$path"'/'"$fixedname" >>"$fixlog"

		fi

		((counter = counter - 1))
	done
}

fix_names() {

	local linecount counter line name path fixedname
	linecount="$(wc -l "$fixchars" | awk '{print $1}')"
	counter="$linecount"
	while ! [ "$counter" -eq 0 ]; do

		line="$(sed -n "${counter}"p "$fixchars")"
		name="$(basename "$line")"
		path="$(dirname "$line")"
		fixedname="$(echo "$name" | tr ':' '-' | tr '\\' '-' | tr '?' '-' | tr '*' '-' | tr '"' '-' | tr '<' '-' | tr '>' '-' | tr '|' '-')"

		if [[ -f "$path"'/'"$fixedname" ]] || [[ -d "$path"'/'"$fixedname" ]]; then

			mv -vf "$line" "$path"'/'"$fixedname"'-'"$(jot -nr 1 100000 999999)" >>"$fixlog"

		else

			mv -vf "$line" "$path"'/'"$fixedname" >>"$fixlog"

		fi

		((counter = counter - 1))
	done
}

function main() {

	# Get the user

	local -r loggedinuser="$(scutil <<<"show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')"

	# Set OneDrive folder name (specify onedrive folder name here)

	local -r onedrivefolder="/Users/""$loggedinuser""/OneDrive"

	# Get date

	local -r fixdate="$(date +%m%d%y-%H%M)"

	# Creating log

	[[ -d "/var/log/onedrive-fixlogs" ]] || mkdir "/var/log/onedrive-fixlogs"

	fixlog="/var/log/onedrive-fixlogs/onedrive-fixlog-""$fixdate"
	readonly fixlog

	echo "$(date +%m%d%y-%H%M)"": Log created at ""$fixlog" | tee "$fixlog"

	# Check if file system is APFS

	local apfscheck
	apfscheck="$(diskutil info / | awk '/Type \(Bundle\)/ {print $3}')"

	if [[ "$apfscheck" == "apfs" ]]; then

		echo "$(date +%m%d%y-%H%M)"": File system is APFS, the script may continue." | tee -a "$fixlog"

	else

		echo "$(date +%m%d%y-%H%M)"": File system not supported, aborting." | tee -a "$fixlog"

		/usr/local/jamf/bin/jamf displayMessage -message "The file system on this Mac is not supported, please upgrade to macOS High Sierra or more recent."

		exit 0

	fi

	# Check if OneDrive folder is present
	# Make backup using APFS clonefile, prevent the backup from being indexed by Spotlight

	if [ -d "$onedrivefolder" ]; then

		echo "$(date +%m%d%y-%H%M)"": OneDrive directory is present. Stopping OneDrive." | tee -a "$fixlog"

		killall OneDrive || true

		beforefix_size=$(du -sk "$onedrivefolder" | awk -F '\t' '{print $1}')
		readonly beforefix_size
		beforefix_filecount=$(find "$onedrivefolder" | wc -l | sed -e 's/^ *//')
		readonly beforefix_filecount

		echo "$(date +%m%d%y-%H%M)"": The OneDrive folder is using ""$beforefix_size"" KB and the file count is ""$beforefix_filecount"" before fixing filenames." | tee -a "$fixlog"

		rm -drf "/Users/""$loggedinuser""/FF-Backup-"??????"-"????
		mkdir -p "/Users/""$loggedinuser""/FF-Backup-""$fixdate""/""$fixdate"".noindex"
		chown "$loggedinuser":staff "/Users/""$loggedinuser""/FF-Backup-""$fixdate"
		chown "$loggedinuser":staff "/Users/""$loggedinuser""/FF-Backup-""$fixdate""/""$fixdate"".noindex"
		touch "/Users/""$loggedinuser""/FF-Backup-""$fixdate""/""$fixdate"".noindex/.metadata_never_index"
		cp -cpR "$onedrivefolder" "/Users/""$loggedinuser""/FF-Backup-""$fixdate""/""$fixdate"".noindex"

		echo "$(date +%m%d%y-%H%M)"": APFS clonefile backup created at /Users/""$loggedinuser""/FF-Backup-""$fixdate""/""$fixdate"".noindex." | tee -a "$fixlog"

	else

		echo "$(date +%m%d%y-%H%M)"": OneDrive directory not present, aborting." | tee -a "$fixlog"

		/usr/local/jamf/bin/jamf displayMessage -message "Cannot find the OneDrive folder. Ask IT to help st up OneDrive, or change the name of the folder"
		exit 0

	fi

	# Fix directory filenames

	echo "$(date +%m%d%y-%H%M)"": Fixing illegal characters in directory names" | tee -a "$fixlog"
	fixchars="$(mktemp)"
	readonly fixchars
	find "${onedrivefolder}" -type d -name '*[\\:*?"<>|]*' -print >"$fixchars"
	fix_names

	echo "$(date +%m%d%y-%H%M)"": Fixing trailing characters in directory names" | tee -a "$fixlog"
	fixtrail="$(mktemp)"
	readonly fixtrail
	find "${onedrivefolder}" -type d -name "* " -print >"$fixtrail"
	find "${onedrivefolder}" -type d -name "*." -print >>"$fixtrail"
	fix_trailing_chars

	echo "$(date +%m%d%y-%H%M)"": Fixing leading spaces in directory names" | tee -a "$fixlog"
	fixlead="$(mktemp)"
	readonly fixlead
	find "${onedrivefolder}" -type d -name " *" -print >"$fixlead"
	fix_leading_spaces

	# Fix all other filenames

	echo "$(date +%m%d%y-%H%M)"": Fixing illegal characters in filenames" | tee -a "$fixlog"

	find "${onedrivefolder}" -name '*[\\:*?"<>|]*' -print >"$fixchars"
	fix_names

	echo "$(date +%m%d%y-%H%M)"": Fixing trailing characters in filenames" | tee -a "$fixlog"
	find "${onedrivefolder}" -name "* " -print >"$fixtrail"
	find "${onedrivefolder}" -name "*." -print >>"$fixtrail"
	fix_trailing_chars

	echo "$(date +%m%d%y-%H%M)"": Fixing leading spaces in filenames" | tee -a "$fixlog"
	find "${onedrivefolder}" -name " *" -print >"$fixlead"
	fix_leading_spaces

	# Check OneDrive directory size and filecount after applying name fixes

	afterfix_size=$(du -sk "$onedrivefolder" | awk -F '\t' '{print $1}')
	readonly afterfix_size
	afterfix_filecount=$(find "$onedrivefolder" | wc -l | sed -e 's/^ *//')
	readonly afterfix_filecount

	echo "$(date +%m%d%y-%H%M)"": The OneDrive folder is using ""$afterfix_size"" KB and the file count is ""$afterfix_filecount"" after fixing filenames. Restarting OneDrive." | tee -a "$fixlog"

	if [[ "$beforefix_filecount" -eq "$afterfix_filecount" ]]; then

		/usr/local/jamf/bin/jamf displayMessage -message "File names have been corrected. A backup has been placed in FF-Backup-$fixdate in your user folder. The backup will be replaced the next time you correct filenames. You may also delete it, should you need more space."

	else

		/usr/local/jamf/bin/jamf displayMessage -message "Something went wrong. A backup has been placed in FF-Backup-$fixdate in your user folder. Ask IT to help restore the backup."

	fi

}

main

finish
