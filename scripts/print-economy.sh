#!/bin/bash

#
# macOS printer economy script: if color queue is selected, revert to grayscale
#
# Also re-adds printers if not present.
#
# Meant to be run as a regular Jamf policy (for example, once per week)
#
# Printer drivers and custom PPDs need to be deployed first.
#
# The script assumes you can adjust color or grayscale printing through a PPD setting, and you need a
# separate print queue for each setting. You will need to create a PPD with each color setting and deploy them,
# then adjust the lpadmin command below to correctly add your printer or print server queue with relevant PPDs.
#

# Get logged in user

loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# If the print queues have been deleted, re-add them

if lpstat -a | grep -q -w "Color_Printer"

then

	echo "Color_Printer exists";

else

	/usr/sbin/lpadmin -p "Color_Printer" -v "smb://printserver/follow_you" -P "/usr/local/ppd/colour_printer.ppd" -o printer-is-shared=false -o auth-info-required=username,password -o printer-is-accepting-jobs=true -o printer-location='Follow You';
	/usr/sbin/cupsenable "Color_Printer";
	/usr/sbin/cupsaccept "Color_Printer";

fi

if lpstat -a | grep -q -w "Grayscale_Printer"

then

	echo "Grayscale_Printer exists";

else

	/usr/sbin/lpadmin -p "Grayscale_Printer" -v "smb://printserver/follow_you" -P "/usr/local/ppd/grayscale.ppd" -o printer-is-shared=false -o auth-info-required=username,password -o printer-is-accepting-jobs=true -o printer-location='Follow You';
	/usr/sbin/cupsenable "Grayscale_Printer";
	/usr/sbin/cupsaccept "Grayscale_Printer";

fi

# Makes black and white default if Color_Printer is currently chosen, does nothing if any other printer is selected

if sudo -u "$loggedInUser" lpstat -d | grep -q -w "Color_Printer"

then

	echo "Color_Printer is standard, reverting to Grayscale_Printer";
	defaults write /Library/Preferences/org.cups.PrintingPrefs UseLastPrinter -bool "FALSE";
	sudo -u "$loggedInUser" /usr/bin/lpoptions -d "Grayscale_Printer";
	/usr/bin/lpoptions -d "Grayscale_Printer";	

else

	echo "Color_Printer is not default, not changing to Grayscale_Printer";
    
fi

exit 0
