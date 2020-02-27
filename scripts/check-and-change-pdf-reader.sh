#!/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

#
# Check if Preview.app is the default PDF reader and change it back if it isn't
#

# Get OS version and logged in user

osVersion=$(/usr/bin/sw_vers -productVersion | awk -F. '{print $2}')

loggedInUser=$(scutil <<<"show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

# Check if Preview.app is the default PDF reader, exit gracefully if it is

if [[ ! $(/usr/bin/sudo -u "$loggedInUser" /usr/local/bin/swda getUTIs | grep com.adobe.pdf | grep Preview) ]]; then
    echo "Preview.app is not the default PDF reader."
else
	echo "Preview.app is the default PDF reader"
	exit 0
fi

# Check OS version and change PDF reader to Preview.app (in a new location on Catalina)

if [[ "$osVersion" -ge 15 ]]; then
	/usr/bin/sudo -u "loggedInUser" /usr/local/bin/swda setHandler --UTI com.adobe.pdf --app /System/Applications/Preview.app
else
    /usr/bin/sudo -u "loggedInUser" /usr/local/bin/swda setHandler --UTI com.adobe.pdf --app /Applications/Preview.app
fi
