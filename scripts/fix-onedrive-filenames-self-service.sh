#!/bin/bash

###################################################################
#
# Jamf Self Service Script to check user's OneDrive folder for illegal
# characters, leading or trailing spaces and correct them to 
# allow smooth synchronization.
#
# Modified by soundsnw, Sunday June 9, 2019
#
# Changelog:
# - Adapted to run from Jamf Self Service, with user messaging
# - Bugfixes, the script was not running properly on recent OS versions
# - Only treats the actual OneDrive folder
# - Makes a backup of the OneDrive folder that can be deleted later (an uncompressed, date-stamped archive on the user's desktop)
#   If there is not sufficient space for the backup and 5 GB of free space in addition, the script will not let the user
#   proceed and indicates how much space needs to be freed.
# - Logs filename changes and script status messages to the /usr/local/onedrivefixlog folder
# - Makes sure relevant status messages are visible in Jamf logs
#
# Important: The OneDrive folder name used in your organization needs to be specified in the script (line 30)
#
# Version: 0.2
#
# Original script by dsavage:
# https://github.com/UoE-macOS/jss/blob/master/utilities-fix-file-names.sh
#
##################################################################

# Set OneDrive folder name (needs to be specified in the script)

onedriveFolder="/Users/$uun/OneDrive"

# Make sure the machine does not sleep until the script is finished

( caffeinate -sim -t 7200 ) & disown;

# Clear any previous temp files

rm /tmp/*.ffn

# Get the user

uun=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`

# Get date and time

BD=`date +%m%d%y-%H%M`

# Set logfile location and create log

fixLogLocation=/usr/local/onedrivefixlog

fixLog="$fixLogLocation/onedrive-log.txt"

filenameFixLog="$fixLogLocation/onedrive-namefixes.txt"

if [ ! -d "$fixLogLocation" ]; then

  echo "$BD: $fixLogLocation does not exist, creating directory."
  mkdir "$fixLogLocation"

else

  echo "$BD: $fixLogLocation exists."

fi

if [ ! -f "$fixLog" ]; then

  echo "$BD: $fixLog does not exist, touching file."
  touch "$fixLog"
  touch "$filenameFixLog"

else

  echo "$BD: $fixLog exists."

fi

# Check if OneDrive folder is present

if [ -d "$onedriveFolder" ] 

then

    echo "$BD: OneDrive directory is present."
    echo "$BD: OneDrive directory is present." >> "$fixLog"

else

    echo "$BD: OneDrive directory not present, aborting."
    echo "$BD: OneDrive directory not present, aborting." >> "$fixLog"

    /usr/local/jamf/bin/jamf displayMessage -message "OneDrive folder does not exist. Set up OneDrive, or change the folder name to your organization's default."

    sleep 3;
 
    exit 1;

fi

# Check if there is sufficient space to make a backup of the OneDrive folder and still have 5G free space

availSpace=$(df "$HOME" | awk 'NR==2 { print $4 }')
availSpaceG="$(($availSpace /2/1024/1024))"

echo "$BD: The disk has $availSpaceG GB free"
echo "$BD: The disk has $availSpaceG GB and $availSpace 512-blocks free" >> "$fixLog"

onedriveSize=$(du -s "$onedriveFolder" | awk -F '\t' '{print $1}')
onedriveSizeG="$(($onedriveSize /2/1024/1024))"

onedriveFileCount=$(find "$onedriveFolder" | wc -l | sed -e 's/^ *//')

echo "$BD: The OneDrive folder is using $onedriveSizeG GB of space and the file count is $onedriveFileCount before fixing filenames."
echo "$BD: The OneDrive folder is using $onedriveSizeG GB and $onedriveSize 512-blocks and the file count is $onedriveFileCount before fixing filenames." >> "$fixLog"

# Set the amount of extra free space in 512-blocks in addition to the space consumed by the OneDrive
# folder required to be able to run the script

reqAdditionalFreeSpace=10490000

# Find the requried space to run the script

reqSpace="$(($onedriveSize + $reqAdditionalFreeSpace))"

neededSpace="$(($reqSpace - $availSpace))"

neededSpaceG="$(($neededSpace /2/1024/1024))"

echo "$BD: The amount of free space required to run the script, in gigabytes, is $neededSpaceG"
echo "$BD: The amount of free space required to run the script, in gigabytes, is $neededSpaceG" >> "$fixLog"

# Check if there is enough available space to run the script, abort if there isn't

if (( availSpace < reqSpace )); then

  echo "$BD: Not enough space to run script, aborting."
  echo "$BD: Not enough space to run script, aborting." >> "$fixLog"

  /usr/local/jamf/bin/jamf displayMessage -message "There isn't enough free space to backup your OneDrive folder before correcting the filenames. Please liberate $neededSpaceG GB and try again."
  
  sleep 3;

  exit 1;

else

  echo "$BD: Sufficient space to run script, continuing.." >> "$fixLog"

fi

/usr/local/jamf/bin/jamf displayMessage -message "This may take a while. Please make sure the machine is connected to a power supply before continuing. Before correcting the file names, we will backup your OneDrive folder to an archive on your Desktop. OneDrive is using $onedriveSizeG GB of space and the number of files to be treated is $onedriveFileCount." 

# Quit OneDrive if it is running

if pgrep OneDrive; then

  killall OneDrive;

fi

# Backup the OneDrive folder

echo "$BD: OneDrive backup started."
echo "$BD: OneDrive backup started." >> "$fixLog"

tar -cvf "/Users/$uun/Desktop/OneDrive-Backup-$BD.tar" "$onedriveFolder" > /dev/null 2>&1

echo "$BD: Backup complete." 
echo "$BD: Backup complete."  >> "$fixLog"

# Remove local fstemps so they won't clog the server

find "$onedriveFolder" -name ".fstemp*" -exec rm -dfR '{}' \;

# Filename correction functions

Check_Trailing_Chars ()
{

cat /tmp/cln.ffn > /tmp/fixtrail.ffn
linecount=`wc -l /tmp/fixtrail.ffn | awk '{print $1}'`
counter=$linecount
echo $linecount

while ! [ "$counter" == 0 ]; do

line="`sed -n ${counter}p /tmp/fixtrail.ffn`"
lastChar="`sed -n ${counter}p /tmp/fixtrail.ffn | grep -Eo '.$'`"

if [ "$lastChar" == " " ] || [ "$lastChar" == "." ]
then
name=`basename "$line"` # get the filename we need to change
path=`dirname "$line"` # dirname to get the path
fixedname=$(echo "$name" | tr '.' '-' | awk '{sub(/[ \t]+$/, "")};1') # remove/replace the trailing whitespace or period
echo "Trailing chars original : $line" >> "$filenameFixLog"
echo "Trailing chars fix      : $path/$fixedname." >> "$filenameFixLog"
mv -vf "$line" "$path/$fixedname" > /dev/null 2>&1 # rename the file or folder

fi

let "counter = $counter -1"
done
}

Check_Leading_Spaces ()
{

cat /tmp/cln.ffn > /tmp/fixlead.ffn

linecount=`wc -l /tmp/fixlead.ffn | awk '{print $1}'`
counter=$linecount
while ! [ "$counter" == 0 ]; do

line="`sed -n ${counter}p /tmp/fixlead.ffn`"
name=`basename "$line"` # get the filename we need to change
path=`dirname "$line"` # dirname to get the path
# sed out the leading whitespace
fixedname=`echo $name | sed -e 's/^[ \t]*//'`
echo "Leading spaces original : $line" >> "$filenameFixLog"
echo "Leading spaces fix      : $path/$fixedname." >> "$filenameFixLog"
# rename the file or folder
mv -vf "$line" "$path/$fixedname" > /dev/null 2>&1

let "counter = $counter -1"
done
}

Fix_Names ()
{
# Count the number of lines
linecount=`wc -l /tmp/${1}.ffn | awk '{print $1}'`
counter=$linecount
while ! [ "$counter" == 0 ]; do

line="`sed -n ${counter}p /tmp/${1}.ffn`"
name=`basename "$line"` # get the filename we need to change
path=`dirname "$line"` # dirname to get the path
fixedname=$(echo "$name" | tr ':' '-' | tr '\\\' '-' | tr '\#\' '-' | tr '?' '-' | tr '*' '-' | tr '"' '-' | tr '<' '-' | tr '>' '-' | tr '%' '-' | tr '|' '-' ) # sed out the leading whitespace
echo "$fixedname" >> /tmp/allfixed.ffn
echo "Illegal characters original : $line" >> "$filenameFixLog"
echo "Illegal characters fix      : $path/$fixedname" >> "$filenameFixLog"
mv -vf "$line" "$path/$fixedname" > /dev/null 2>&1 # rename the file or folder

let "counter = $counter -1"
done
}

# Fix the filenames

echo "$BD: Applying filename fixes.."
echo "$BD: Applying filename fixes.." >> "$fixLog"
echo "$BD: Applying filename fixes.." >> "$filenameFixLog"

echo "$BD: Fixing illegal characters.."
echo "$BD: Fixing illegal characters.." >> "$fixLog"
echo "$BD: Fixing illegal characters.." >> "$filenameFixLog"

find "${onedriveFolder}" -name '*[\\/:*?"<>%|]*' -print >> /tmp/acln.ffn

Fix_Names acln
sleep 1
echo "$BD: Fixed illegal chars"
echo "$BD: Fixed illegal chars" >> "$fixLog"
echo "$BD: Fixed illegal chars" >> "$filenameFixLog"
rm -f /tmp/cln.ffn

echo "$BD: Fixing trailing characters.."
echo "$BD: Fixing trailing characters.." >> "$fixLog"
echo "$BD: Fixing trailing characters.." >> "$filenameFixLog"

find "${onedriveFolder}" -name "*" >> /tmp/cln.ffn

Check_Trailing_Chars
echo "$BD: Fixed trailing spaces and periods."
echo "$BD: Fixed trailing spaces and periods." >> "$fixLog"
echo "$BD: Fixed trailing spaces and periods." >> "$filenameFixLog"
sleep 1
rm -f /tmp/cln.ffn

echo "$BD: Fixing leading spaces.."
echo "$BD: Fixing leading spaces.." >> "$fixLog"
echo "$BD: Fixing leading spaces.." >> "$filenameFixLog"

find "${onedriveFolder}" -name "*" >> /tmp/cln.ffn

Check_Leading_Spaces
echo "$BD: Fixed leading spaces."
echo "$BD: Fixed leading spaces." >> "$fixLog"
echo "$BD: Fixed leading spaces." >> "$filenameFixLog"
sleep 1
rm -f /tmp/cln.ffn

# Restart OneDrive

echo "$BD: OneDrive is using $onedriveSizeG GB of space and the file count is $onedriveFileCount after correcting filenames."
echo "$BD: OneDrive is using $onedriveSizeG GB of space and $onedriveSize 512-blocks and the file count is $onedriveFileCount after correcting filenames." >> "$fixLog"

echo "$BD: Restarting OneDrive."
echo "$BD: Restarting OneDrive." >> "$fixLog"

open /Applications/OneDrive.app

sleep 15

/usr/local/jamf/bin/jamf displayMessage -message "File names have been corrected. A backup of the OneDrive folder has been made on the Desktop. You may delete the backup later, at your convenience."

sleep 1

if pgrep caffeinate; then

	killall caffeinate;

fi

exit 0;
