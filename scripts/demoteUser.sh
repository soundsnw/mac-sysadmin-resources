#!/bin/zsh
emulate -LR zsh # reset zsh options
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Simple Zsh tempadmin v0.1
#
# Catalina compatible script for Jamf Self Service to grant standard
# users temporary admin rights.
#
# Modified by snowsnd, original code by Armin Briegel

# Indicate how long the user should have admin privileges here
privilegeMinutes=15

# If timestamp file is not present, exit quietly 
if [[ ! -e /usr/local/tatime ]]; then
    echo "No timestamp, exiting."
    exit 0
fi

currentUser=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

# If no current user is logged in, exit quietly
if [[ -z "$currentUser" ]]; then
    # no user logged in
    echo "No user logged in, exiting"
    exit 0
fi

# If FileVault is not yet enabled, exit quietly
# (Uncomment if you use FileVault)

#fvStatus="$(fdesetup status)"

#if [[ "$fvStatus" != "FileVault is On."* ]]; then
#    echo "Filevault not (yet) enabled, exiting"
#    exit 0
#fi

# If user is a standard user, exit
if dseditgroup -o checkmember -m "$currentUser" admin; then
	echo "User is an admin."
else
	exit 0
fi

# Check if the specified time has passed since privileges were given

# Get current Unix time
currentEpoch="$(date +%s)"
echo "Current Unix time: ""$currentEpoch"
# Get user promotion timestamp
timeStamp="$(stat -f%c /usr/local/tatime)"
echo "Unix time when admin was given: ""$timeStamp"
# Seconds since user was promoted
timeSinceAdmin="$((currentEpoch - timeStamp))"
echo "Seconds since admin was given: ""$timeSinceAdmin"

privilegeSeconds="$((privilegeMinutes * 60))"

# If timestamp exists and the specified time has passed, remove admin

if [[ -e /usr/local/tatime ]] && [[ (( $timeSinceAdmin -gt $privilegeSeconds )) ]]; then

 	echo "60 minutes have passed, removing admin"
	# Remove user from the admin group
	dseditgroup -o edit -d "$currentUser" -t user admin
    # Make sure timestamp file is not present and run recon
    mv -vf /usr/local/tatime /usr/local/tatime.old
    /usr/local/jamf/bin/jamf recon

fi

exit 0
