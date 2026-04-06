#!/bin/sh

# 
# Provides standard user access to preference panels they would expect to be able to access, and might need access to.
#

# Provides standard users access to system preferences

/usr/bin/security authorizationdb write system.preferences allow

# Provides standard users access to network preferences

/usr/bin/security authorizationdb write system.preferences.network allow
/usr/bin/security authorizationdb write system.services.systemconfiguration.network allow

# Provides standard users access to printing preferences

/usr/bin/security authorizationdb write system.preferences.printing allow
/usr/bin/security authorizationdb write system.print.admin allow
/usr/sbin/dseditgroup -o edit -a staff -t group lpadmin

# Provides standard users access to energy saver

/usr/bin/security authorizationdb write system.preferences.energysaver allow

# Provides standard users access to Find My Mac

#/usr/bin/security authorizationdb write com.apple.AOSNotification.FindMyMac.modify allow
