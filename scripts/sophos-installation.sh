#!/bin/bash

#
# Sophos Installation Script
# 
# Assumes pre-deployment of Sophos Installer.app to 
# /usr/local/deploy/sophos/
#

# Fix permissions on installer
/usr/sbin/chown -R root:wheel "/usr/local/deploy/sophos/Sophos Installer.app"
/bin/chmod a-w "/usr/local/deploy/sophos/Sophos Installer.app"
/bin/chmod a+x "/usr/local/deploy/sophos/Sophos Installer.app/Contents/MacOS/Sophos Installer"
/bin/chmod a+x "/usr/local/deploy/sophos/Sophos Installer.app/Contents/MacOS/tools/com.sophos.bootstrap.helper"

# Run the Sophos installer
sudo /usr/local/deploy/sophos/Sophos\ Installer.app/Contents/MacOS/Sophos\ Installer --install

# Cleanup
/bin/rm -rf "/usr/local/deploy/sophos"
/usr/bin/killall "Sophos Installer"

exit 0
