#!/bin/zsh
export PATH=/usr/bin:/bin:/usr/sbin:sbin

recommendedUpdates=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist RecommendedUpdates | wc -l | awk '{print $1}')

if [[ recommendedUpdates -gt 2 ]]; then
echo "<result>True</result>"
else
echo "<result>False</result>"
fi