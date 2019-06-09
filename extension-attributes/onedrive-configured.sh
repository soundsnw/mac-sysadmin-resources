#!/bin/sh

# 
# Jamf Extension Attribute
#
# Checks if OneDrive is configured by seeing if the OneDrive folder is present, which would be the case after initial configuration.
# 

loggedInUser=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`

if [[ -d "/Users/$loggedInUser/OneDrive" ]] ; then
	echo "<result>Yes</result>"
else
    echo "<result>No</result>"
fi
