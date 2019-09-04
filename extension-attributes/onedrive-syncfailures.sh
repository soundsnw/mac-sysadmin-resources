
#!/bin/bash

loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' );

onedriveFolder="/Users/$loggedInUser/OneDrive"

if [[ -d "$onedriveFolder" ]] ; then

find "${onedriveFolder}" -name '*[\\:*?"<>|]*' -print > /tmp/odfailures
find "${onedriveFolder}" -name "* " -print >> /tmp/odfailures
find "${onedriveFolder}" -name "*." -print >> /tmp/odfailures
find "${onedriveFolder}" -name " *" -print >> /tmp/odfailures

odsyncfailures=$(cat /tmp/odfailures | wc -l | sed -e 's/^ *//')

echo "<result>$odsyncfailures</result>"

else

echo "<result>0</result>"

fi
