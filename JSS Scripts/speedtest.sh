#!/bin/zsh

####################################################################################################
#
#   swiftDialog Speedtest
#   
#
#   Purpose: Self Service Policy to run a networkquality test, display status to user and update
#   Jamf Pro
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 31-Jan-2023, Kris Cloutier (@Kris-Cloutier)
#   Original version
#
#
####################################################################################################

####################################################################################################
#
#   Parameter Fields
#       4: Icon
#       5: Org Name for Script File
#       6:
#       7:
#       8:
#       9:
#       10:
#       11:
#
####################################################################################################

########################################### Variables ##############################################

dialog_log=$(mktemp /var/tmp/dialog.XXX)
chmod 644 ${dialog_log}
script_log="/var/tmp/org.${5}.log"
if [[ -n ${4} ]]; then iconoption="--icon"; icon="${4}"; fi
overlay_icon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
dialog_app="/usr/local/bin/dialog"
network_log="/tmp/networkresults.txt"

############################################ Functions #############################################

# Update log file
function updateLog() {
    echo "$(date) ${1}" >> $script_log
}

# Update dialog command file
function dialogCMD() {
    echo "${1}" >> "${dialog_log}"
    sleep 0.1
}

# Launch Dialog 
function launchDialog(){
    updateLog "launching main dialog..."
    progress_text="Please wait while the test starts..."
    open -a "/Library/Application Support/Dialog/Dialog.app" --args --title "Testing Network Bandwidth" --message "Testing your network bandwidth against Apple's servers" --icon "${icon}" --overlayicon "${overlay_icon}" --mini --progress 4 --commandfile "${dialog_log}"
    updateLog "main dialog running..."
}

# Use networkquality command to test network then save results to txt file
function networkTest(){
    updateLog "preforming network test..."
    dialogCMD "progresstext: Preforming network test..."
    networkquality > ${network_log}
    dialogCMD "progress: increment"
    sleep 1
    
}

# Run recon
function updateJamf(){
    updateLog "updating Jamf Pro inventory..."
    dialogCMD "progresstext: Gathering computer information..."
    dialogCMD "progress: increment"
    /usr/local/bin/jamf recon >> ${script_log}
    dialogCMD "progresstext: Submitting computer information..."
    dialogCMD "progress: increment"
    sleep 5
    dialogCMD "progresstext: Completed"
    dialogCMD "progress: complete"
    sleep 3
    dialogCMD "quit:"
}

# Display results in new dialog
function dialogResults(){
	updateLog "launching results dialog..."
    updateLog "reading network results..."
    down=$(awk 'NR==3 { print; exit }' /tmp/networkresults.txt)
    upload=$(awk 'NR==2 { print; exit }' /tmp/networkresults.txt)
    latency=$(awk 'NR==5 { print; exit }' /tmp/networkresults.txt)
    ${dialog_app} \
        --title "Testing Network Bandwidth" \
        --message "### Network Results\n\n**Download:** ${down}\n\n**Upload:** ${upload}\n\n**Latency:** ${latency}" \
        --icon "${icon}" \
        --overlayicon "${overlay_icon}" \
        --button1text "Close" \
        --commandfile "${dialog_log}"
    updateLog "results dialog running"
}

# Cleanly quit script and remove tmp file, credit @bartreardon
function quitScript() {
	updateLog "quitscript was called"
    dialogcmd "quit: "
    sleep 1
    updateLog "Exiting"
    # brutal hack - need to find a better way
    killall tail
    if [[ -e ${dialog_log} ]]; then
        updateLog "removing ${dialog_log}"
		rm "${dialog_log}"
    fi
    exit 0
}

# Check the repo for latest version, update if necessary, credit @acodega
function dialogCheck(){
  # Get the URL of the latest PKG From the Dialog GitHub repo
  dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

  # Expected Team ID of the downloaded PKG
  expectedDialogTeamID="PWA5E9TQ59"

  # Check for Dialog and install if not found
  if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

    updateLog "Dialog not found. Installing..."

    # Create temporary working directory
    workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

    # Download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

    # Verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

    # Install the package if Team ID validates
    if [ "$expectedDialogTeamID" = "$teamID" ] || [ "$expectedDialogTeamID" = "" ]; then
 
      /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /

    else

      jamfDisplayMessage "Dialog Team ID verification failed."
      exit 1

    fi
 
    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"  

  else

    updateLog "swiftDialog version $(dialog --version) found; proceeding..."

  fi

}

# Main function
function main(){

    updateLog "**** START ****"
    updateLog "Running dialogCheck function"
    dialogCheck
    updateLog "Running launchDialog function"
    launchDialog
    updateLog "Running networkTest function"
    networkTest
    updateLog "Running updateJamf function"
    updateJamf
    updateLog "Running dialog results function"
    dialogResults
    updateLog "All Done!"
    updateLog "**** END ****"
    quitScript
}

main
exit 0