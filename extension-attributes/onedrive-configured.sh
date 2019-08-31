#!/bin/sh

# 
# Jamf Extension Attribute
#
# Checks if OneDrive is configured by seeing if the OneDrive folder is present, which would be the case after initial configuration.
# 

loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if [[ -d "/Users/$loggedInUser/OneDrive" ]] ; then
	echo "<result>Yes</result>"
else
    echo "<result>No</result>"
fi
