#!/bin/bash

# Convert logged in user to standard user if the user has admin privileges

loggedInUser=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`

if id -G $loggedInUser | grep -q -w 80 ; 
    then 
        /usr/sbin/dseditgroup -o edit -d $loggedInUser -t user admin;
        echo "User '$loggedInUser' has been converted to a standard user";
    else 
    echo "User '$loggedInUser' does not have admin privileges";
fi
