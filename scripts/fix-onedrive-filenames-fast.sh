#!/bin/bash

###################################################################
#
# Jamf Self Service Script to check user's OneDrive folder for illegal
# characters, leading or trailing spaces and corrects them to 
# allow smooth synchronization.
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
# Important: The OneDrive folder name used in your organization needs to be specified in the script (line 37)
#
# Version: 0.2.2
#
# Original script by dsavage:
# https://github.com/UoE-macOS/jss/blob/master/utilities-fix-file-names.sh
#
##################################################################

# Get the user

uun=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Set OneDrive folder name (needs to be specified in the script)

onedriveFolder="/Users/$uun/OneDrive"

# Make sure the machine does not sleep until the script is finished

( caffeinate -sim -t 7200 ) & disown;

# Clear any previous temp files

rm /tmp/*.ffn

# Check if OneDrive folder is present

if [ -d "$onedriveFolder" ] 

then

    echo "$(date +%m%d%y-%H%M): OneDrive directory is present."

else

    echo "$(date +%m%d%y-%H%M): OneDrive directory not present, aborting."

    /usr/local/jamf/bin/jamf displayMessage -message "OneDrive folder does not exist. Set up OneDrive, or change the folder name to your organization's default."

    sleep 3;
 
    exit 0;

fi

# Check if there is sufficient space to make a backup of the OneDrive folder and still have 5G free space

#onedriveSize=$(du -s "$onedriveFolder" | awk -F '\t' '{print $1}')
#onedriveSizeG="$((onedriveSize /2/1024/1024))"
#onedriveFileCount=$(find "$onedriveFolder" | wc -l | sed -e 's/^ *//')

#echo "$(date +%m%d%y-%H%M): The OneDrive folder is using $onedriveSizeG GB of space and the file count is $onedriveFileCount before fixing filenames."

/usr/local/jamf/bin/jamf displayMessage -message "Fixing OneDrive filenames. Please be patient and wait until you are notified that the process is finished."

# Quit OneDrive if it is running

if pgrep OneDrive; then

  killall OneDrive;

fi

# Remove local fstemps so they won't clog the server

find "$onedriveFolder" -name ".fstemp*" -exec rm -dfR '{}' \;

# Filename correction functions

Check_Trailing_Chars ()
{

linecount=$(wc -l /tmp/fixtrail.ffn | awk '{print $1}')
counter=$linecount
echo "$linecount"

while ! [ "$counter" == 0 ]; do

line="$(sed -n "${counter}"p /tmp/fixtrail.ffn)"
lastChar="$(sed -n "${counter}"p /tmp/fixtrail.ffn | grep -Eo '.$')"

if [ "$lastChar" == " " ] || [ "$lastChar" == "." ]
then
name=$(basename "$line") # get the filename we need to change
path=$(dirname "$line") # dirname to get the path
fixedname=$(echo "$name" | tr '.' '-' | awk '{sub(/[ \t]+$/, "")};1') # remove/replace the trailing whitespace or period
#echo "Trailing chars original : $line"
#echo "Trailing chars fix      : $path/$fixedname"
mv -f "$line" "$path/$fixedname" > /dev/null 2>&1 # rename the file or folder

fi

(( counter = counter -1  ))
done
}

Check_Leading_Spaces ()
{

linecount=$(wc -l /tmp/fixlead.ffn | awk '{print $1}')
counter=$linecount
while ! [ "$counter" == 0 ]; do

line="$(sed -n "${counter}"p /tmp/fixlead.ffn)"
name=$(basename "$line") # get the filename we need to change
path=$(dirname "$line") # dirname to get the path
# sed out the leading whitespace
fixedname=$(echo "$name" | sed -e 's/^[ \t]*//')
#echo "Leading spaces original : $line"
#echo "Leading spaces fix      : $path/$fixedname"
# rename the file or folder
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
name=$(basename "$line") # get the filename we need to change
path=$(dirname "$line") # dirname to get the path
fixedname=$(echo "$name" | tr ':' '-' | tr '\\\' '-' | tr '?' '-' | tr '*' '-' | tr '"' '-' | tr '<' '-' | tr '>' '-' | tr '|' '-' ) # sed out illegal characters
echo "$fixedname" >> /tmp/allfixed.ffn
#echo "Illegal characters original : $line"
#echo "Illegal characters fix      : $path/$fixedname"
mv -f "$line" "$path/$fixedname" > /dev/null 2>&1 # rename the file or folder

(( counter = counter -1 ))
done
}

# Fix the filenames

echo "$(date +%m%d%y-%H%M): Applying filename fixes.."

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

# Report number of files and size after fixes

#afterFixSize=$(du -s "$onedriveFolder" | awk -F '\t' '{print $1}')
#afterFixSizeG="$((afterFixSize /2/1024/1024))"
#afterFixFileCount=$(find "$onedriveFolder" | wc -l | sed -e 's/^ *//')

#echo "$(date +%m%d%y-%H%M): The OneDrive folder is using $afterFixSizeG GB of space and the file count is $afterFixFileCount after fixing filenames."

# Restart OneDrive

#echo "$(date +%m%d%y-%H%M): Restarting OneDrive."

open /Applications/OneDrive.app

sleep 5

/usr/local/jamf/bin/jamf displayMessage -message "File names have been corrected."

sleep 1

if pgrep caffeinate; then

  killall caffeinate;

fi

exit 0;
