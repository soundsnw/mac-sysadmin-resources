#!/bin/bash

# Output Firefox Policy to /Applications/Firefox.app/Contents/Resources/distribution/policies.json

if [ ! -d "/Applications/Firefox.app/Contents/Resources/distribution" ]
then
    mkdir "/Applications/Firefox.app/Contents/Resources/distribution"
fi

(
sudo cat <<'EOD'
{
	"policies": {
		"DisableTelemetry": true,
		"DisplayBookmarksToolbar": true,
		"DontCheckDefaultBrowser": true,
		"OverrideFirstRunPage": "https://www.google.com/",
		"OverridePostUpdatePage": "https://www.google.com/",
		"HomepageURL": "https://www.google.com/",
		"DisableBuiltinPDFViewer": true,
		"DisableFeedbackCommands": true,
		"DisableFirefoxAccounts": true,
		"DisableFirefoxStudies": true,
		"TrackingProtection": true,
		"DisableAppUpdate": false,
		"BlockAboutConfig": true,
		"NoDefaultBookmarks": true,
		"InstallAddonsPermission": {
			"Allow": "https://addons.mozilla.org/",
			"Default": true
		},
		"EnableTrackingProtection": {
			"Value": true,
			"Locked": false
		},
		"Bookmarks": [{
				"Title": "Word",
				"URL": "https://www.office.com/launch/word",
				"Placement": "toolbar"
			},
			{
				"Title": "PowerPoint",
				"URL": "https://www.office.com/launch/powerpoint",
				"Placement": "toolbar"
			},
			{
				"Title": "Excel",
				"URL": "https://www.office.com/launch/excel",
				"Placement": "toolbar"
			}
		]
	}
}
EOD
) > "/Applications/Firefox.app/Contents/Resources/distribution/policies.json"

# Set app ownership to logged in user and group to staff, so automatic updates will work for standard users

loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}' )

/usr/sbin/chown -R $loggedInUser:staff "/Applications/Firefox.app"

# Add Firefox to the dock, using dockutil (needs to be pre-deployed to /usr/local/mdmtools/dockutil)

sudo -u $loggedInUser /usr/local/mdmtools/dockutil --add "/Applications/Firefox.app" --position middle