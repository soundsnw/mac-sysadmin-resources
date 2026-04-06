#!/bin/bash

# Convert logged in user to admin user

loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

/usr/sbin/dseditgroup -o edit -a $loggedInUser -t user admin
