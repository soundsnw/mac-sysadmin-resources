#!/bin/bash

###################################################################
#
# Jamf Self Service Script to check user's OneDrive folder for illegal
# characters, leading or trailing spaces and corrects them to 
# allow smooth synchronization.
#
# Modified by soundsnw, September 8, 2019
#
# Important: The OneDrive folder name used in your organization 
# needs to be specified in the script 
# (line 174)
#
# Changelog
# September 8, 2019
# - Treats directories first
# - If the corrected filename is used by another file, appends a random number at the end
# - Checks if the number of files before and after renaming is the same
# - Checks if required commands are present
# - Uses mktemp for temp files
# - Restarts OneDrive and cleans up temp files if aborted
# - Uses local and readonly variables where appropriate
#
# September 4, 2019
# - Changed backup parent directory to user folder to avoid potential problems if Desktop sync is turned on
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
# Version: 0.5
#
# Original script by dsavage:
# https://github.com/UoE-macOS/jss/blob/master/utilities-fix-file-names.sh
#
##################################################################

set -o pipefail

# Checks for presence of required commands

if [[ -f /bin/cp ]] && [[ -f /usr/bin/touch ]] && [[ -f /usr/bin/jot ]] && [[ -f /usr/sbin/chown ]] && [[ -f /usr/bin/find ]] && [[ -f /usr/bin/du ]] && [[ -f /usr/sbin/diskutil ]] && [[ -f /usr/bin/tee ]] && [[ -f /bin/date ]] && [[ -f /bin/mkdir ]] && [[ -f /usr/sbin/scutil ]] && [[ -f /usr/bin/sed ]] && [[ -f /bin/mv ]] && [[ -f /usr/bin/tr ]] && [[ -f /usr/bin/dirname ]] && [[ -f /usr/bin/basename ]] && [[ -f /usr/bin/awk ]] && [[ -f /usr/bin/wc ]] && [[ -f /bin/rm ]] && [[ -f /usr/bin/pgrep ]] && [[ -f /usr/bin/open ]] && [[ -f /usr/bin/killall ]] && [[ -f /usr/bin/caffeinate ]]; then

	echo "Required commands are present."

else

	echo "Required commands are not present, aborting."
	exit 1

fi

unset fixchars fixtrail fixlead

# Cleanup function, removes temp files and restarts OneDrive

function finish() {

	[[ -z "$fixchars" ]] || /bin/rm -f "$fixchars"
	[[ -z "$fixtrail" ]] || /bin/rm -f "$fixtrail"
	[[ -z "$fixlead" ]] || /bin/rm -f "$fixlead"

	[[ $(/usr/bin/pgrep "OneDrive") ]] || /usr/bin/open -gj "/Applications/OneDrive.app"

	[[ $(/usr/bin/pgrep "caffeinate") ]] || /usr/bin/killall "caffeinate"

	exit 0

}
trap finish EXIT HUP INT QUIT TERM

# Make sure the machine does not sleep until the script is finished

(/usr/bin/caffeinate -sim -t 3600) &
disown

# Filename correction functions

fix_trailing_chars() {

	local linecount counter line name path fixedname
	linecount="$(/usr/bin/wc -l "$fixtrail" | /usr/bin/awk '{print $1}')"
	counter="$linecount"

	while ! [ "$counter" == 0 ]; do

		line="$(/usr/bin/sed -n "${counter}"p "$fixtrail")"
		name="$(/usr/bin/basename "$line")"
		path="$(/usr/bin/dirname "$line")"
		fixedname="$(echo "$name" | /usr/bin/tr '.' '-' | /usr/bin/awk '{sub(/[ \t]+$/, "")};1')"

		if [[ -f "$path"'/'"$fixedname" ]] || [[ -d "$path"'/'"$fixedname" ]]; then

			/bin/mv -vf "$line" "$path"'/'"$fixedname"'-'"$(/usr/bin/jot -nr 1 10000000 99999999)" >>"$fixlog"

		else

			/bin/mv -vf "$line" "$path"'/'"$fixedname" >>"$fixlog"

		fi

		((counter = counter - 1))
	done
}

fix_leading_spaces() {

	local linecount counter line name path fixedname
	linecount="$(/usr/bin/wc -l "$fixlead" | /usr/bin/awk '{print $1}')"
	counter="$linecount"
	while ! [ "$counter" == 0 ]; do

		line="$(/usr/bin/sed -n "${counter}"p "$fixlead")"
		name="$(/usr/bin/basename "$line")"
		path="$(/usr/bin/dirname "$line")"
		fixedname="$(echo "$name" | /usr/bin/sed -e 's/^[ \t]*//')"

		if [[ -f "$path"'/'"$fixedname" ]] || [[ -d "$path"'/'"$fixedname" ]]; then

			/bin/mv -vf "$line" "$path"'/'"$fixedname"'-'"$(/usr/bin/jot -nr 1 10000000 99999999)" >>"$fixlog"

		else

			/bin/mv -vf "$line" "$path"'/'"$fixedname" >>"$fixlog"

		fi

		((counter = counter - 1))
	done
}

fix_names() {

	local linecount counter line name path fixedname
	linecount="$(/usr/bin/wc -l "$fixchars" | /usr/bin/awk '{print $1}')"
	counter="$linecount"
	while ! [ "$counter" == 0 ]; do

		line="$(/usr/bin/sed -n "${counter}"p "$fixchars")"
		name="$(/usr/bin/basename "$line")"
		path="$(/usr/bin/dirname "$line")"
		fixedname="$(echo "$name" | /usr/bin/tr ':' '-' | /usr/bin/tr '\\' '-' | /usr/bin/tr '?' '-' | /usr/bin/tr '*' '-' | /usr/bin/tr '"' '-' | /usr/bin/tr '<' '-' | /usr/bin/tr '>' '-' | /usr/bin/tr '|' '-')"

		if [[ -f "$path"'/'"$fixedname" ]] || [[ -d "$path"'/'"$fixedname" ]]; then

			/bin/mv -vf "$line" "$path"'/'"$fixedname"'-'"$(/usr/bin/jot -nr 1 10000000 99999999)" >>"$fixlog"

		else

			/bin/mv -vf "$line" "$path"'/'"$fixedname" >>"$fixlog"

		fi

		((counter = counter - 1))
	done
}

function main() {

	# Get the user

	local -r loggedinuser="$(/usr/sbin/scutil <<<"show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }')"

	# Set OneDrive folder name

	local -r onedrivefolder="/Users/""$loggedinuser""/OneDrive"

	# Get date

	local -r fixdate="$(/bin/date +%m%d%y-%H%M)"

	# Creating log

	[[ -d "/usr/local/onedrive-fixlogs" ]] || /bin/mkdir "/usr/local/onedrive-fixlogs"

	fixlog="/usr/local/onedrive-fixlogs/onedrive-fixlog-""$fixdate"
	readonly fixlog

	echo "$(/bin/date +%m%d%y-%H%M)"": Log created at ""$fixlog" | /usr/bin/tee "$fixlog"

	# Check if file system is APFS

	local apfscheck="$(/usr/sbin/diskutil info / | /usr/bin/awk '/Type \(Bundle\)/ {print $3}')"

	if [[ "$apfscheck" == "apfs" ]]; then

		echo "$(/bin/date +%m%d%y-%H%M): File system is APFS, the script may continue." | /usr/bin/tee -a "$fixlog"

	else

		echo "$(/bin/date +%m%d%y-%H%M): File system not supported, aborting." | /usr/bin/tee -a "$fixlog"

		/usr/local/jamf/bin/jamf displayMessage -message "The file system on this Mac is not supported, please upgrade to macOS High Sierra or more recent."

		exit 0

	fi

	# Check if OneDrive folder is present
	# Make backup using APFS clonefile, prevent the backup from being indexed by Spotlight

	if [ -d "$onedrivefolder" ]; then

		echo "$(/bin/date +%m%d%y-%H%M): OneDrive directory is present. Stopping OneDrive." | /usr/bin/tee -a "$fixlog"

		/usr/bin/killall OneDrive || true

		beforefix_size=$(/usr/bin/du -sk "$onedrivefolder" | /usr/bin/awk -F '\t' '{print $1}')
		readonly beforefix_size
		beforefix_filecount=$(/usr/bin/find "$onedrivefolder" | /usr/bin/wc -l | /usr/bin/sed -e 's/^ *//')
		readonly beforefix_filecount

		echo "$(/bin/date +%m%d%y-%H%M)"": The OneDrive folder is using ""$beforefix_size"" KB and the file count is ""$beforefix_filecount"" before fixing filenames." | /usr/bin/tee -a "$fixlog"

		/bin/rm -dRf "/Users/""$loggedinuser""/FF-Backup-"[0-1][0-9][0-3][0-9][1-2][0-9]-[0-2][0-9][0-6][0-9]
		/bin/mkdir -p "/Users/""$loggedinuser""/FF-Backup-""$fixdate""/""$fixdate.noindex"
		/usr/sbin/chown "$loggedinuser":staff "/Users/""$loggedinuser""/FF-Backup-""$fixdate"
		/usr/sbin/chown "$loggedinuser":staff "/Users/""$loggedinuser""/FF-Backup-""$fixdate""/""$fixdate.noindex"
		/usr/bin/touch "/Users/""$loggedinuser""/FF-Backup-""$fixdate""/""$fixdate"".noindex/.metadata_never_index"
		/bin/cp -cpR "$onedrivefolder" "/Users/""$loggedinuser""/FF-Backup-""$fixdate""/""$fixdate.noindex"

		echo "$(/bin/date +%m%d%y-%H%M)"": APFS clonefile backup created at /Users/""$loggedinuser""/FF-Backup-""$fixdate""/""$fixdate"".noindex." | /usr/bin/tee -a "$fixlog"

	else

		echo "$(/bin/date +%m%d%y-%H%M)"": OneDrive directory not present, aborting." | /usr/bin/tee -a "$fixlog"

		/usr/local/jamf/bin/jamf displayMessage -message "Cannot find the OneDrive folder. Ask IT to help st up OneDrive, or change the name of the folder"
		exit 0

	fi

	# Fix directory filenames

	echo "$(/bin/date +%m%d%y-%H%M): Fixing illegal characters in directory names" | /usr/bin/tee -a "$fixlog"
	fixchars="$(/usr/bin/mktemp)"
	readonly fixchars
	/usr/bin/find "${onedrivefolder}" -type d -name '*[\\:*?"<>|]*' -print >"$fixchars"
	fix_names

	echo "$(/bin/date +%m%d%y-%H%M): Fixing trailing characters in directory names" | /usr/bin/tee -a "$fixlog"
	fixtrail="$(/usr/bin/mktemp)"
	readonly fixtrail
	/usr/bin/find "${onedrivefolder}" -type d -name "* " -print >"$fixtrail"
	/usr/bin/find "${onedrivefolder}" -type d -name "*." -print >>"$fixtrail"
	fix_trailing_chars

	echo "$(/bin/date +%m%d%y-%H%M): Fixing leading spaces in directory names" | /usr/bin/tee -a "$fixlog"
	fixlead="$(/usr/bin/mktemp)"
	readonly fixlead
	/usr/bin/find "${onedrivefolder}" -type d -name " *" -print >"$fixlead"
	fix_leading_spaces

	# Fix all other filenames

	echo "$(/bin/date +%m%d%y-%H%M): Fixing illegal characters in filenames" | /usr/bin/tee -a "$fixlog"

	/usr/bin/find "${onedrivefolder}" -name '*[\\:*?"<>|]*' -print >"$fixchars"
	fix_names

	echo "$(/bin/date +%m%d%y-%H%M): Fixing trailing characters in filenames" | /usr/bin/tee -a "$fixlog"
	/usr/bin/find "${onedrivefolder}" -name "* " -print >"$fixtrail"
	/usr/bin/find "${onedrivefolder}" -name "*." -print >>"$fixtrail"
	fix_trailing_chars

	echo "$(/bin/date +%m%d%y-%H%M): Fixing leading spaces in filenames" | /usr/bin/tee -a "$fixlog"
	/usr/bin/find "${onedrivefolder}" -name " *" -print >"$fixlead"
	fix_leading_spaces

	# Check OneDrive directory size and filecount after applying name fixes

	afterfix_size=$(/usr/bin/du -sk "$onedrivefolder" | /usr/bin/awk -F '\t' '{print $1}')
	readonly afterfix_size
	afterfix_filecount=$(/usr/bin/find "$onedrivefolder" | /usr/bin/wc -l | /usr/bin/sed -e 's/^ *//')
	readonly afterfix_filecount

	echo "$(/bin/date +%m%d%y-%H%M)"": The OneDrive folder is using ""$afterfix_size"" KB and the file count is ""$afterfix_filecount"" after fixing filenames. Restarting OneDrive." | /usr/bin/tee -a "$fixlog"

	if [[ "$beforefix_filecount" == "$afterfix_filecount" ]]; then

		/usr/local/jamf/bin/jamf displayMessage -message "File names have been corrected. A backup has been placed in FF-Backup-$fixdate in your user folder. The backup will be replaced the next time you correct filenames. You may also delete it, should you need more space."

	else

		/usr/local/jamf/bin/jamf displayMessage -message "Something went wrong. A backup has been placed in FF-Backup-$fixdate in your user folder. Ask IT to help restore the backup."

	fi

}

main

finish
