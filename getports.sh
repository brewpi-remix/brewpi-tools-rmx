#!/bin/bash

############
### Set up script constants
############

declare DOFTP=false # FTP the results
declare FTPUSER=""
declare FTPPSSW=""
declare FTPHOST=""
declare FTPPORT=""
declare THISSCRIPT="getports.sh"
declare CMDLINE="curl -L debug.brewpiremix.com | sudo bash"
#declare CMDLINE="sudo /home/pi/brewpi-tools-rmx/$THISSCRIPT"
# Should not have to edit past here
declare SCRIPTNAME="${THISSCRIPT%%.*}"
declare TARBALL="$(date +%F_%k:%M:%S)-$SCRIPTNAME.tar.gz"
declare HOMEPATH=""
declare -i devNum=0

############
### Check privileges and permissions
############

checkroot() {
  if [ -n "$SUDO_USER" ]; then REALUSER="$SUDO_USER"; else REALUSER="$(whoami)"; fi
  if [[ "$EUID" -ne 0 ]]; then
    sudo -n true 2> /dev/null
    local retval="$?"
    if [[ "$retval" == "0" ]]; then
      echo -e "\nNot runing as root, relaunching correctly.\n"
      sleep 2
      eval "$CMDLINE"
      exit "$?"
    else
      # sudo not available, give instructions
      echo -e "\nThis script must be run with root priviledges."
      echo -e "Enter the following command as one line:"
      echo -e "$CMDLINE" 1>&2
      exit 1
    fi
  fi
  # And get the user home directory
  local shadow=$( (getent passwd "$REALUSER") 2>&1)
  retval="$?"
  if [ "$retval" -eq 0 ]; then
    HOMEPATH=$(echo "$shadow" | cut -d':' -f6)
  else
    echo -e "\nUnable to retrieve $REALUSER's home directory. Manual install"
    echo -e "may be necessary."
    exit 1
  fi
}

############
### Step through ports and create data dumps
############

doPort() {
  local device=""
  local devices=$(ls /dev/ttyACM* /dev/ttyUSB* /dev/rfcomm* 2> /dev/null)
  # Get a list of USB and BT TTY devices
  [ -n "$devices" ] && echo -e "\nWalking device trees.\n"
  for device in $devices; do
    # Walk device tree | awk out the stanza with the last device in chain
    local dev=$(echo "$device" | cut -d"/" -f3)
    echo -e "Outputting $device to $HOMEPATH/$dev.device."
    udevadm info --a -n "$device" > "$HOMEPATH/$dev.device"
    ((++devNum))
  done
}

############
### Create TARBALL for submission
############

doTar() {
  echo -e "\nAdding files to tarball:"
  find "$HOMEPATH" -name "*.device" -print0 | tar -cvzf "$HOMEPATH/$TARBALL" --null -T -
  find "$HOMEPATH" -name "*.device" -type f -exec rm '{}' \;
}

############
### Transfer TARBALL
############

doFTP() {
  # TODO
  echo -e "\nTransfer functionality not implemented."
}

############
### Main
############

main() {
  checkroot
  doPort
  [ "$devNum" -gt 0 ] && doTar
  "$DOFTP" && doFTP || echo -e "\nPlease email $HOMEPATH/$TARBALL to Lee@Bussy.org."
}

############
### Start script execution
############

main && exit 0

