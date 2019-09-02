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
# August 31, 2019
# - Corrected syntax with advice from shellcheck
# - Updated the manner in which the logged-in user is found:
#   https://erikberglund.github.io/2018/Get-the-currently-logged-in-user,-in-Bash/
# - The correct time is now used in logs instead of the initial time the script was run being used throughout 
#
# June 9, 2019:
# - Adapted to run from Jamf Self Service, with user messaging
# - Bugfixes, the script was not running properly on recent OS versions
# - Only treats the actual OneDrive folder
# - Makes a backup of the OneDrive folder that can be deleted later (an uncompressed, date-stamped archive on the user's desktop)
#   If there is not sufficient space for the backup and 5 GB of free space in addition, the script will not let the user
#   proceed and indicates how much space needs to be freed.
# - Logs filename changes and script status messages to the /usr/local/onedrivefixlog folder
# - Makes sure relevant status messages are visible in Jamf logs
#
# Important: The OneDrive folder name used in your organization needs to be specified in the script (line 55)
#
# Version: 0.2.2
#
# Original script by dsavage:
# https://github.com/UoE-macOS/jss/blob/master/utilities-fix-file-names.sh
#
##################################################################

# Make sure the machine does not sleep until the script is finished

( caffeinate -sim -t 7200 ) & disown;

# Get the user

uun=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Set OneDrive folder name (needs to be specified in the script)

onedriveFolder="/Users/$uun/OneDrive"

# Clear any previous temp files

rm /tmp/*.ffn

# Set logfile location and create log

fixLogLocation=/usr/local/onedrivefixlog

fixLog="$fixLogLocation/onedrive-log.txt"

filenameFixLog="$fixLogLocation/onedrive-namefixes.txt"

if [ ! -d "$fixLogLocation" ]; then

  echo "$(date +%m%d%y-%H%M): $fixLogLocation does not exist, creating directory."
  mkdir "$fixLogLocation"

else

  echo "$(date +%m%d%y-%H%M): $fixLogLocation exists."

fi

if [ ! -f "$fixLog" ]; then

  echo "$(date +%m%d%y-%H%M): $fixLog does not exist, touching logfiles."
  touch "$fixLog"
  touch "$filenameFixLog"

else

  echo "$(date +%m%d%y-%H%M): $fixLog exists."

fi

# Check if OneDrive folder is present

if [ -d "$onedriveFolder" ] 

then

    echo "$(date +%m%d%y-%H%M): OneDrive directory is present."
    echo "$(date +%m%d%y-%H%M): OneDrive directory is present." >> "$fixLog"

else

    echo "$(date +%m%d%y-%H%M): OneDrive directory not present, aborting."
    echo "$(date +%m%d%y-%H%M): OneDrive directory not present, aborting." >> "$fixLog"

    /usr/local/jamf/bin/jamf displayMessage -message "OneDrive folder does not exist. Set up OneDrive, or change the folder name to your organization's default."

    sleep 3;
 
    exit 0;

fi

# Check if there is sufficient space to make a backup of the OneDrive folder and still have 5G free space

availSpace=$(df "$HOME" | awk 'NR==2 { print $4 }')
availSpaceG="$((availSpace /2/1024/1024))"

echo "$(date +%m%d%y-%H%M): The disk has $availSpaceG GB free"
echo "$(date +%m%d%y-%H%M): The disk has $availSpaceG GB and $availSpace 512-blocks free" >> "$fixLog"

onedriveSize=$(du -s "$onedriveFolder" | awk -F '\t' '{print $1}')
onedriveSizeG="$((onedriveSize /2/1024/1024))"

onedriveFileCount=$(find "$onedriveFolder" | wc -l | sed -e 's/^ *//')

echo "$(date +%m%d%y-%H%M): The OneDrive folder is using $onedriveSizeG GB of space and the file count is $onedriveFileCount before fixing filenames."
echo "$(date +%m%d%y-%H%M): The OneDrive folder is using $onedriveSizeG GB of space and the file count is $onedriveFileCount before fixing filenames." >> "$fixLog"

# Set the amount of extra free space in 512-blocks in addition to the space consumed by the OneDrive
# folder required to be able to run the script

reqAdditionalFreeSpace=10490000

# Find the requried space to run the script

reqSpace="$((onedriveSize + reqAdditionalFreeSpace))"

neededSpace="$((reqSpace - availSpace))"

neededSpaceG="$((neededSpace /2/1024/1024))"

echo "$(date +%m%d%y-%H%M): The amount of free space required to run the script, in gigabytes, is $neededSpaceG"
echo "$(date +%m%d%y-%H%M): The amount of free space required to run the script, in gigabytes, is $neededSpaceG" >> "$fixLog"

# Check if there is enough available space to run the script, abort if there isn't

if (( availSpace < reqSpace )); then

  echo "$(date +%m%d%y-%H%M): Not enough space to run script, aborting."
  echo "$(date +%m%d%y-%H%M): Not enough space to run script, aborting." >> "$fixLog"

  /usr/local/jamf/bin/jamf displayMessage -message "There isn't enough free space to backup your OneDrive folder before correcting the filenames. Please liberate $neededSpaceG GB and try again."
  
  sleep 3;

  exit 0;

else

  echo "$(date +%m%d%y-%H%M): Sufficient space to run script, continuing.." >> "$fixLog"

fi

/usr/local/jamf/bin/jamf displayMessage -message "This may take a while. Please make sure the machine is connected to a power supply before continuing. Before correcting the file names, we will backup your OneDrive folder to an archive on your Desktop. OneDrive is using $onedriveSizeG GB of space and the number of files to be treated is $onedriveFileCount." 

# Quit OneDrive if it is running

if pgrep OneDrive; then

  killall OneDrive;

fi

# Backup the OneDrive folder

echo "$(date +%m%d%y-%H%M): OneDrive backup started."
echo "$(date +%m%d%y-%H%M): OneDrive backup started." >> "$fixLog"

tar -cvf "/Users/$uun/Desktop/OneDrive-Backup-$(date +%m%d%y-%H%M).tar" "$onedriveFolder" > /dev/null 2>&1

echo "$(date +%m%d%y-%H%M): Backup complete." 
echo "$(date +%m%d%y-%H%M): Backup complete."  >> "$fixLog"

# Filename correction functions

Check_Trailing_Chars ()
{

linecount=$(wc -l /tmp/fixtrail.ffn | awk '{print $1}')
counter=$linecount

while ! [ "$counter" == 0 ]; do

line="$(sed -n "${counter}"p /tmp/fixtrail.ffn)"
name=$(basename "$line") # get the filename we need to change
path=$(dirname "$line") # dirname to get the path
fixedname=$(echo "$name" | tr '.' '-' | awk '{sub(/[ \t]+$/, "")};1') # remove/replace the trailing whitespace or period
echo "Trailing chars original : $line" >> "$filenameFixLog"
echo "Trailing chars fix      : $path/$fixedname" >> "$filenameFixLog"
mv -f "$line" "$path/$fixedname" > /dev/null 2>&1 # rename the file or folder

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
echo "Leading spaces original : $line" >> "$filenameFixLog"
echo "Leading spaces fix      : $path/$fixedname" >> "$filenameFixLog"
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
fixedname=$(echo "$name" | tr ':' '-' | tr '\\\' '-' | tr '?' '-' | tr '*' '-' | tr '"' '-' | tr '<' '-' | tr '>' '-' | tr '|' '-' ) # sed out the leading whitespace
echo "$fixedname" >> /tmp/allfixed.ffn
echo "Illegal characters original : $line" >> "$filenameFixLog"
echo "Illegal characters fix      : $path/$fixedname" >> "$filenameFixLog"
mv -f "$line" "$path/$fixedname" > /dev/null 2>&1 # rename the file or folder

(( counter = counter -1 ))
done
}

# Fix the filenames

echo "$(date +%m%d%y-%H%M): Applying filename fixes.."
echo "$(date +%m%d%y-%H%M): Applying filename fixes.." >> "$fixLog"
echo "$(date +%m%d%y-%H%M): Applying filename fixes.." >> "$filenameFixLog"

echo "$(date +%m%d%y-%H%M): Fixing illegal characters.."
echo "$(date +%m%d%y-%H%M): Fixing illegal characters.." >> "$fixLog"
echo "$(date +%m%d%y-%H%M): Fixing illegal characters.." >> "$filenameFixLog"

find "${onedriveFolder}" -name '*[\\:*?"<>|]*' -print >> /tmp/fixchars.ffn

Fix_Names fixchars
sleep 1
echo "$(date +%m%d%y-%H%M): Fixed illegal chars"
echo "$(date +%m%d%y-%H%M): Fixed illegal chars" >> "$fixLog"
echo "$(date +%m%d%y-%H%M): Fixed illegal chars" >> "$filenameFixLog"

echo "$(date +%m%d%y-%H%M): Fixing trailing characters.."
echo "$(date +%m%d%y-%H%M): Fixing trailing characters.." >> "$fixLog"
echo "$(date +%m%d%y-%H%M): Fixing trailing characters.." >> "$filenameFixLog"

find "${onedriveFolder}" -name "* " >> /tmp/fixtrail.ffn
find "${onedriveFolder}" -name "*." >> /tmp/fixtrail.ffn

Check_Trailing_Chars
echo "$(date +%m%d%y-%H%M): Fixed trailing spaces and periods."
echo "$(date +%m%d%y-%H%M): Fixed trailing spaces and periods." >> "$fixLog"
echo "$(date +%m%d%y-%H%M): Fixed trailing spaces and periods." >> "$filenameFixLog"
sleep 1

echo "$(date +%m%d%y-%H%M): Fixing leading spaces.."
echo "$(date +%m%d%y-%H%M): Fixing leading spaces.." >> "$fixLog"
echo "$(date +%m%d%y-%H%M): Fixing leading spaces.." >> "$filenameFixLog"

find "${onedriveFolder}" -name " *" >> /tmp/fixlead.ffn

Check_Leading_Spaces
echo "$(date +%m%d%y-%H%M): Fixed leading spaces."
echo "$(date +%m%d%y-%H%M): Fixed leading spaces." >> "$fixLog"
echo "$(date +%m%d%y-%H%M): Fixed leading spaces." >> "$filenameFixLog"
sleep 1

# Report number of files and size after fixes

afterFixSize=$(du -s "$onedriveFolder" | awk -F '\t' '{print $1}')
afterFixSizeG="$((afterFixSize /2/1024/1024))"
afterFixFileCount=$(find "$onedriveFolder" | wc -l | sed -e 's/^ *//')

echo "$(date +%m%d%y-%H%M): The OneDrive folder is using $afterFixSizeG GB of space and the file count is $afterFixFileCount after fixing filenames."
echo "$(date +%m%d%y-%H%M): The OneDrive folder is using $afterFixSizeG GB of space and the file count is $afterFixFileCount after fixing filenames." >> "$fixLog"

# Restart OneDrive

echo "$(date +%m%d%y-%H%M): Restarting OneDrive."
echo "$(date +%m%d%y-%H%M): Restarting OneDrive." >> "$fixLog"

open /Applications/OneDrive.app

sleep 15

/usr/local/jamf/bin/jamf displayMessage -message "File names have been corrected. A backup of the OneDrive folder has been made on the Desktop. You may delete the backup later, at your convenience."

sleep 3

if pgrep caffeinate; then
  killall caffeinate;
fi

exit 0;
