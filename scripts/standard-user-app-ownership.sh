#!/bin/bash

#
# Sets App ownership to the logged in user, and adjusts group rights to staff
#
# For certain apps, adjusting the rights might help achieve full functionality when running an app as a standard user.
# Meant to be run as part of a MDM policy deploying an app, as a script set to run after other policy actions.
#
# I only recommend using this if an app does not behave as expected when run as a standard user, for example if app auto-updates
# or other functionality does not work as expected, and after testing whether it helps and the app runs well with different rights.
#
# Important: Supply the full path of the app in Jamf's parameter $4 when adding the script to a deployment policy
#

# Finds current user

currentUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

# Changes app ownership to user:staff

/usr/sbin/chown -R $currentUser:staff $4
