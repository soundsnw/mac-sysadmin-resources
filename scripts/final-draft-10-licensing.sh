#!/bin/bash

#
# Final Draft 10 post-install licensing script
# (also disables automatic updates)
#
# Run after deploying Final Draft.
#
# Supply serial in Jamf's script parameter $4, hard-code the license directly in the script or encrypt it for extra security:
# https://github.com/jamf/Encrypted-Script-Parameters
#

loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

echo "Deleting any previous licenses";

rm -f "/Library/Preferences/FLEXnet Publisher/FLEXnet/fnldrft_009b4d00_event.log";
rm -f "/Library/Preferences/FLEXnet Publisher/FLEXnet/fnldrft_009b4d00_tsf.data";
rm -f "/Library/Preferences/FLEXnet Publisher/FLEXnet/fnldrft_009b4d00_tsf.data_backup.001";

sudo -u $loggedInUser defaults delete com.finaldraft.finaldraft.v.10

echo "Installing new license"

sudo -u $loggedInUser defaults write com.finaldraft.finaldraft.v10 IT-Install $4

sudo -u $loggedInUser defaults write com.finaldraft.finaldraft.v10 IT-Install-NoPrompt -bool yes

sudo -u $loggedInUser defaults write com.finaldraft.finaldraft.v10 SUEnableAutomaticChecks -bool no

exit 0
