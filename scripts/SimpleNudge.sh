#!/bin/zsh
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
description="Your Mac has important operating system updates available."
button1="See Updates"
icon="/Library/Application Support/YourCompany/yourlogo.png"
title="Update Notification"
heading="Please Update macOS"

"$jamfHelper" -windowType utility -description "$description" -title "$title" -heading "$heading" -button1 "$button1" -icon "$icon"

loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

sudo -u "$loggedInUser" open "x-apple.systempreferences:com.apple.preferences.softwareupdate"
