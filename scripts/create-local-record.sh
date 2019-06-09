#!/bin/bash

#
# create-local-record.sh
#
# Creates a local XML record with JSS information from Jamf: id, udid, serial, mac address, asset tag,
# username and name, email and department - for later use in scripts and automation.
#
# Script by soundsnw 2019
#

# Prerequisites:
# - Jamf API User w/ Read Permssion for Computer Objects
#  (Create in Jamf, under Jamf Pro User Accounts & Groups)
# 
# For best security, create a user specifically for this purpose with a non-standard username,
# only give the user read access to Computer Objects, and use a random 15-20 character user password.
# DO NOT use an admin user with broad read and write access.
#
# Get the string to put after 'authorization: Basic' with this shell command:
# printf "username:password" | iconv -t ISO-8859-1 | base64 -i -
#
# The string is an obfuscated combination of username and password.
#
# Replace organization.jamfcloud.com below with your organization's Jamf Pro cloud URL.
#
# Find other information to read and modify in the API reference:
# https://developer.jamf.com/apis/classic-api/index
#
# See example of using information from the local record and writing to the record in Jamf at the end.
# Optionally add extra credential obfuscation: https://github.com/jamf/Encrypted-Script-Parameters
#

# Find serial number

serial=`/usr/sbin/system_profiler SPHardwareDataType | /usr/bin/awk '/Serial\ Number\ \(system\)/ {print $NF}'`

mkdir /usr/local/records

/usr/bin/curl --tlsv1.2 -X GET https://organization.jamfcloud.com/JSSResource/computers/match/$serial --header 'authorization: Basic cGeoLe6nuPKwnzwqTAG2WdTLxHzt6Nnd7goV4csz' --header 'Accept: text/xml' -o /usr/local/records/computer_info_raw.xml > /dev/null 2>&1

/usr/bin/xmllint --format /usr/local/records/computer_info_raw.xml --output /usr/local/records/computer_info.xml

rm -f /usr/local/records/computer_info_raw.xml

exit 0

#
# Example use: Use email in local record to set Microsoft Office activation email address
#
## Fetch and display email from local record
# userEmail=$(cat /usr/local/records/computer_info.xml | sed -n -e 's/.*<email>\(.*\)<\/email>.*/\1/p')
# echo "User email: $userEmail"
#
## Set Office activation email address to email from Jamf
# defaults write com.microsoft.office OfficeActivationEmailAddress $userEmail
#
# (More information: https://macadmins.software)

#
# Example use: Write information to Jamf computer record
#
# To write the asset tag defined below to a Jamf computer record from a local script using the API, use the curl command below
#
# Prerequisites:
# - A Jamf API user specifically for the purpose, as described above, with a strong password and non-standard username.
#   (Important: Limit write access to what you will update)
#
# API users with write access are potentially more destructive than read-only users, and you should, ideally,
# enable them only while needed and disable them afterwards, and run scripts that write to Jamf records from
# your admin workstation and not locally, like in this example.
#
# Keep in mind that writing to a Jamf computer record will not update a local record like the one created above. 
# The record would have to be re-downloaded to be up-to-date.
#

## Define Asset tag
## Hard-coded here, but you could make a script to match these up with the correct JSS id and write
## them to the JSS using information from an asset management database and shell commands and utilities 
## like sed, awk and cut
# assetTag=562199
#
## Get JSS id from local record
# jssid=$(cat /usr/local/records/computer_info.xml | sed -n -e 's/.*<id>\(.*\)<\/id>.*/\1/p')
#
## Write asset tag to computer record
# /usr/bin/curl --tlsv1.2 -X PUT -H 'authorization: Basic cGeoLe6nuPKwnzwqTAG2WdTLxHzt6Nnd7goV4csz' -H "Content-Type: text/xml" -d "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?> <computer> <general> <asset_tag>${assetTag}</asset_tag> </general> </computer>" https://organization.jamfcloud.com/JSSResource/computers/id/${jssid} > /dev/null
#
