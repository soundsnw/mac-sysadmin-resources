#!/bin/sh

#
# Checks if OneDrive is running
# 

if [[ ! $(/usr/bin/pgrep "OneDrive") ]]; then 
	echo "<result>No</result>"
else
    echo "<result>Yes</result>"
fi
