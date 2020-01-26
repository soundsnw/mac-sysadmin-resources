#!/bin/zsh
emulate -LR zsh # Reset zsh options
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Simple Zsh tempadmin v0.1
#
# Catalina compatible script for Jamf Self Service to grant standard
# users temporary admin rights.
#
# Modified by soundsnw, original code by Armin Briegel

currentUser=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

# If no current user is logged in, exit quietly
if [[ -z "$currentUser" ]]; then
    echo "No user logged in, exiting"
    exit 0
fi

# Check if the current user already in the admin group
if dseditgroup -o checkmember -m "$currentUser" admin; then
    echo "$currentUser is already in the admin group"
else
    # Create timestamp file
    echo "Creating timestamp"
    touch "/usr/local/tatime"
    chmod 600 "/usr/local/tatime"
    # Run Jamf recon to activate the demote script
    echo "Running recon"
    /usr/local/jamf/bin/jamf recon
    # Add the user to the admin group
    echo "Adding $currentUser to the admin group"
    dseditgroup -o edit -a "$currentUser" -t user admin
fi

exit 0
