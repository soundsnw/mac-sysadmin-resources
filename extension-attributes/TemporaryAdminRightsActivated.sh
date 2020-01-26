#!/bin/sh

# Simple Zsh tempadmin v0.1: Jamf Extension Attribute
#
# Checks if temporary admin rights have been activated, by 
# checking for the presence of an associated timestamp file

if [[ -e "/usr/local/tatime" ]] ; then
	echo "<result>Yes</result>"
else
    echo "<result>No</result>"
fi
