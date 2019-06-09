#!/bin/bash

#
# decaffeinate.sh
# Quits caffeinate if the process is running
#
# Simple script meant to be run after a large installation or other time-consuming procedure, if caffeinate.sh was
# run before the installation
#

if pgrep caffeinate; then

	killall caffeinate;

fi

exit 0
