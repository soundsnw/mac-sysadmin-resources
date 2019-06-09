#!/bin/bash

# 
# caffeinate.sh
# 
# Prevents computer sleep. Use Jamf's parameter $4 to indicate the number of hours to prevent sleep,
# if you are not using the hard-coded value in seconds present in the script.
#
# Useful before large installations. Use decaffeinate.sh after the installation is complete.
#

# Closes caffeinate if it is already running

if pgrep caffeinate; then

	killall caffeinate;
    
fi

# Starts caffeinate and disinherits the process so it stays alive after the script has finished

declare -i AWAKE_TIME

AWAKE_TIME=7200

if [ "$4" ] && [ "$4" -lt "49" ]; then

AWAKE_TIME=$4*3600

fi

echo Machine will not sleep for $AWAKE_TIME seconds.

( caffeinate -sim -t $AWAKE_TIME ) &

disown

exit
