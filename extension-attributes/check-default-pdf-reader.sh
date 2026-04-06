#!/bin/sh
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Check if Preview.app is the default PDF reader

loggedInUser=$(scutil <<<"show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

if [[ ! $(/usr/bin/sudo -u "$loggedInUser" /usr/local/orgutils/swda getUTIs | grep com.adobe.pdf | grep Preview) ]]; then
    echo "<result>No</result>"
else
    echo "<result>Yes</result>"
fi
