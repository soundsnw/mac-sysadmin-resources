#!/bin/bash

###################################################################
#
# Jamf Self Service Script to check user's OneDrive folder for illegal
# characters, leading or trailing spaces and corrects them to 
# allow smooth synchronization.
#
# Modified by soundsnw, September 3, 2019
#
# Changelog
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
# Important: The OneDrive folder name used in your organization needs to be specified in the script (line 48)
#
# Version: 0.3
#
# Original script by dsavage:
# https://github.com/UoE-macOS/jss/blob/master/utilities-fix-file-names.sh
#
##################################################################

# Make sure the machine does not sleep until the script is finished

( caffeinate -sim -t 3600 ) & disown;

# Clear any previous temp files

rm /tmp/*.ffn

# Get the user

uun=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' );

# Set OneDrive folder name

onedriveFolder="/Users/$uun/OneDrive"

# Get date

BD=$(date +%m%d%y-%H%M)

# Creating log

mkdir "/usr/local/onedrive-fixlogs"
touch "/usr/local/onedrive-fixlogs/onedrive-fixlog-$BD"
fixLog="/usr/local/onedrive-fixlogs/onedrive-fixlog-$BD"

echo "$(date +%m%d%y-%H%M): Log created at $fixLog" | tee -a "$fixLog"

# Check if file system is APFS

boot_filesystem_check=$(/usr/sbin/diskutil info / | awk '/Type \(Bundle\)/ {print $3}')

if [[ "$boot_filesystem_check" = "apfs" ]]; then

  echo "$(date +%m%d%y-%H%M): File system is APFS, the script may continue." | tee -a "$fixLog"

else

  echo "$(date +%m%d%y-%H%M): File system not supported, aborting." | tee -a "$fixLog"

  jamf displayMessage -message "The file system on this Mac is not supported, please upgrade to macOS 10.13 or more recent." 
  exit 0;

fi

# Check if OneDrive folder is present
# Make backup using APFS clonefile, prevent the backup from being indexed by Spotlight

if [ -d "$onedriveFolder" ]

then

	echo "$(date +%m%d%y-%H%M): OneDrive directory is present. Stopping OneDrive." | tee -a "$fixLog"

	killall OneDrive

	echo "$(date +%m%d%y-%H%M): The OneDrive folder is using $(du -sk "$onedriveFolder" | awk -F '\t' '{print $1}') KB and the file count is $(find "$onedriveFolder" | wc -l | sed -e 's/^ *//') before fixing filenames." | tee -a "$fixLog"

	rm -drf /Users/"$uun"/Backup-??????-????
	mkdir -p "/Users/$uun/Backup-$BD/$BD.noindex"
	chown "$uun":staff "/Users/$uun/Backup-$BD"
	chown "$uun":staff "/Users/$uun/Backup-$BD/$BD.noindex"
	touch "/Users/$uun/Backup-$BD/$BD.noindex/.metadata_never_index"
	/bin/cp -cpR "$onedriveFolder" "/Users/$uun/Backup-$BD/$BD.noindex"

	echo "$(date +%m%d%y-%H%M): APFS clonefile backup created at /Users/$uun/Backup-$BD/$BD.noindex." | tee -a "$fixLog"

else

  echo "$(date +%m%d%y-%H%M): OneDrive directory not present, aborting." | tee -a "$fixLog"

  jamf displayMessage -message "OneDrive is not configured. Ask IT to help you set up OneDrive, or change the name of the OneDrive folder."
  
  exit 0;

fi

# Filename correction functions

Check_Trailing_Chars ()
{

linecount=$(wc -l /tmp/fixtrail.ffn | awk '{print $1}')
counter=$linecount

while ! [ "$counter" == 0 ]; do

line="$(sed -n "${counter}"p /tmp/fixtrail.ffn)"
name=$(basename "$line")
path=$(dirname "$line")
fixedname=$(echo "$name" | tr '.' '-' | awk '{sub(/[ \t]+$/, "")};1')
mv -vf "$line" "$path/$fixedname" >> "$fixLog"

(( counter = counter -1 ))
done
}

Check_Leading_Spaces ()
{

linecount=$(wc -l /tmp/fixlead.ffn | awk '{print $1}')
counter=$linecount
while ! [ "$counter" == 0 ]; do

line="$(sed -n "${counter}"p /tmp/fixlead.ffn)"
name=$(basename "$line")
path=$(dirname "$line")
fixedname=$(echo "$name" | sed -e 's/^[ \t]*//')
mv -vf "$line" "$path/$fixedname" >> "$fixLog"

(( counter = counter -1 ))
done
}

Fix_Names ()
{

linecount=$(wc -l /tmp/"${1}".ffn | awk '{print $1}')
counter=$linecount
while ! [ "$counter" == 0 ]; do

line="$(sed -n "${counter}"p /tmp/"${1}".ffn)"
name=$(basename "$line")
path=$(dirname "$line")
fixedname=$(echo "$name" | tr ':' '-' | tr '\\\' '-' | tr '?' '-' | tr '*' '-' | tr '"' '-' | tr '<' '-' | tr '>' '-' | tr '|' '-' )
mv -vf "$line" "$path/$fixedname" >> "$fixLog"

(( counter = counter -1 ))
done
}

# Fix the filenames

echo "$(date +%m%d%y-%H%M): Fixing illegal characters" | tee -a "$fixLog"
find "${onedriveFolder}" -name '*[\\:*?"<>|]*' -print >> /tmp/fixchars.ffn
Fix_Names fixchars

echo "$(date +%m%d%y-%H%M): Fixing trailing characters" | tee -a "$fixLog"
find "${onedriveFolder}" -name "* " >> /tmp/fixtrail.ffn
find "${onedriveFolder}" -name "*." >> /tmp/fixtrail.ffn
Check_Trailing_Chars

echo "$(date +%m%d%y-%H%M): Fixing leading spaces" | tee -a "$fixLog"
find "${onedriveFolder}" -name " *" >> /tmp/fixlead.ffn
Check_Leading_Spaces

echo "$(date +%m%d%y-%H%M): The OneDrive folder is using $(du -sk "$onedriveFolder" | awk -F '\t' '{print $1}') KB and the file count is $(find "$onedriveFolder" | wc -l | sed -e 's/^ *//') after fixing filenames. Restarting OneDrive." | tee -a "$fixLog"

jamf displayMessage -message "OneDrive file names have been fixed, so they can sync properly. A backup copy has been made in the Backup-$BD folder in your user folder. The backup will be replaced the next time you correct filenames. You may also delete it, should you need more free space." 

# Clean up and restart OneDrive

rm /tmp/*.ffn

open /Applications/OneDrive.app

killall caffeinate

exit 0
