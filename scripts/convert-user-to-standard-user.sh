#!/bin/bash

# Convert logged in user to standard user if the user has admin privileges 

loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if id -G $loggedInUser | grep -q -w 80 ; 
    then 
        /usr/sbin/dseditgroup -o edit -d $loggedInUser -t user admin;
        echo "User '$loggedInUser' has been converted to a standard user";
    else 
    echo "User '$loggedInUser' does not have admin privileges";
fi
