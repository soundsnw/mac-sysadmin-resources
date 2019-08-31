#!/bin/bash

#
# OneDrive kickstart script
#
# Checks if user has set up OneDrive, and if it's running.
#
# If user has set up OneDrive, and it's not running, restarts OneDrive.
#

# Get logged in user

loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Check if the OneDrive folder is present

if [ -d "/Users/$loggedInUser/OneDrive" ]; then
    echo "User has configured OneDrive."
else
	echo "User hasn't set up OneDrive, aborting."
	exit 1;
fi

# Check if OneDrive is running

if [[ ! $(/usr/bin/pgrep "OneDrive") ]]; then
	echo "OneDrive is inactive, restarting client.";
	sudo -u $loggedInUser open "/Applications/OneDrive.app"
else
    echo "OneDrive is already running.";
fi

exit 0
