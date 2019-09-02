#!/bin/bash

###################################################################
#
# Jamf Self Service Script to check user's OneDrive folder for illegal
# characters, leading or trailing spaces and corrects them to 
# allow smooth synchronization.
#
# The script will work fine without Jamf, just remove it from the script (it is used for popups with user messaging)
#
# Modified by soundsnw, September 2, 2019
#
# Changelog
#
# September 2, 2019
# - Only does rename operations on relevant files (much faster)
# - Now comes in a fast and slow version (with and without backup and reporting)
# - No longer fixes # or %, which are supported in more recent versions of OneDrive
#   https://support.office.com/en-us/article/invalid-file-names-and-file-types-in-onedrive-onedrive-for-business-and-sharepoint-64883a5d-228e-48f5-b3d2-eb39e07630fa#invalidcharacters
# - Changed all exit status codes to 0, to keep things looking tidy in Self Service
# 
# For info on previous changes, see the other version of the script
#
# Important: The OneDrive folder name used in your organization needs to be specified in the script (line 41)
#
# Version: 0.2.2
#
# Original script by dsavage:
# https://github.com/UoE-macOS/jss/blob/master/utilities-fix-file-names.sh
#
##################################################################

# Make sure the machine does not sleep until the script is finished

( caffeinate -sim -t 3600 ) & disown;

# Get the user

uun=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Set OneDrive folder name (needs to be specified in the script)

onedriveFolder="/Users/$uun/OneDrive"

# Clear any previous temp files

rm /tmp/*.ffn

# Check if OneDrive folder is present

if [ -d "$onedriveFolder" ] 

then

    echo "OneDrive directory is present."

else

    echo "$OneDrive directory not present, aborting."
    /usr/local/jamf/bin/jamf displayMessage -message "OneDrive folder does not exist. Set up OneDrive, or change the folder name to your organization's default."
    exit 0;

fi

/usr/local/jamf/bin/jamf displayMessage -message "Fixing OneDrive filenames. Please be patient and wait until you are notified that the process is finished."

killall OneDrive

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
mv -f "$line" "$path/$fixedname" > /dev/null 2>&1

(( counter = counter -1  ))
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
mv -f "$line" "$path/$fixedname" > /dev/null 2>&1

(( counter = counter -1 ))
done
}

Fix_Names ()
{
# Count the number of lines
linecount=$(wc -l /tmp/"${1}".ffn | awk '{print $1}')
counter=$linecount
while ! [ "$counter" == 0 ]; do

line="$(sed -n "${counter}"p /tmp/"${1}".ffn)"
name=$(basename "$line")
path=$(dirname "$line")
fixedname=$(echo "$name" | tr ':' '-' | tr '\\\' '-' | tr '?' '-' | tr '*' '-' | tr '"' '-' | tr '<' '-' | tr '>' '-' | tr '|' '-' )
mv -f "$line" "$path/$fixedname" > /dev/null 2>&1

(( counter = counter -1 ))
done
}

# Fix the filenames

find "${onedriveFolder}" -name '*[\\:*?"<>|]*' -print >> /tmp/fixchars.ffn
Fix_Names fixchars
sleep 1

find "${onedriveFolder}" -name "* " >> /tmp/fixtrail.ffn
find "${onedriveFolder}" -name "*." >> /tmp/fixtrail.ffn
Check_Trailing_Chars
sleep 1

find "${onedriveFolder}" -name " *" >> /tmp/fixlead.ffn
Check_Leading_Spaces
sleep 1

# Restart OneDrive

open /Applications/OneDrive.app

/usr/local/jamf/bin/jamf displayMessage -message "File names have been corrected."

killall caffeinate

exit 0;
