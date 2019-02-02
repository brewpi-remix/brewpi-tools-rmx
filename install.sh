#!/bin/bash

# Copyright (C) 2018  Lee C. Bussy (@LBussy)

# This file is part of LBussy's BrewPi Tools Remix (BrewPi-Tools-RMX).
#
# BrewPi Tools RMX is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# BrewPi Tools RMX is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with BrewPi Tools RMX. If not, see <https://www.gnu.org/licenses/>.

# These scripts were originally a part of brewpi-tools, an installer for
# the BrewPi project. Legacy support (for the very popular Arduino
# controller) seems to have been discontinued in favor of new hardware.

# All credit for the original brewpi-tools goes to @elcojacobs,
# @vanosg, @routhcr, @ajt2 and I'm sure many more contributors around
# the world. My apologies if I have missed anyone; those were the names
# listed as contributors on the Legacy branch.

# See: 'original-license.md' for notes about the original project's
# license and credits.

############
### Init
############

func_doinit() {
  # Change to current dir so we can get the git info
  cd "$(dirname "$0")"
  
  # Set up some project constants
  THISSCRIPT="$(basename "$0")"
  SCRIPTNAME="${THISSCRIPT%%.*}"
  if [ -x "$(command -v git)" ] && [ -d .git ]; then
    VERSION="$(git describe --tags $(git rev-list --tags --max-count=1))"
    GITURL="$(git config --get remote.origin.url)"
    GITPROJ="$(basename $GITURL)"
    GITPROJ="${GITPROJ%.*}"
    PACKAGE="${GITPROJ^^}"
    GITPROJWWW="brewpi-www-rmx"
    GITPROJSCRIPT="brewpi-script-rmx"
    # Concatenate URLs
    GITURLWWW="${GITURL/$GITPROJ/$GITPROJWWW}"
    GITURLSCRIPT="${GITURL/$GITPROJ/$GITPROJSCRIPT}"
  else
    echo -e "\nNot a valid git repository. Did you copy this file here?"
    exit 1
  fi
}
  
############
### Functions for --help and --version functionality
############

# func_usage outputs to stdout the --help usage message.
func_usage () {
  echo -e "$PACKAGE $THISSCRIPT version $VERSION
Usage: sudo ./$THISSCRIPT"
}
# func_version outputs to stdout the --version message.
func_version () {
  echo -e "$THISSCRIPT ($PACKAGE) $VERSION
Copyright (C) 2018 Lee C. Bussy (@LBussy)
This is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published
by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.
<https://www.gnu.org/licenses/>
There is NO WARRANTY, to the extent permitted by law."
}
func_arguments() {
  if test $# = 1; then
    case "$1" in
      --help | --hel | --he | --h )
        func_usage; exit 0 ;;
      --version | --versio | --versi | --vers | --ver | --ve | --v )
        func_version; exit 0 ;;
    esac
  fi
}

############
### Check privileges and permissions
############

func_checkroot() {
  ### Check if we have root privs to run
  if [[ $EUID -ne 0 ]]; then
     echo -e "This script must be run as root: sudo ./$THISSCRIPT" 1>&2
     exit 1
  fi
  # And get the user home directory
  if [ $SUDO_USER ]; then REALUSER=$SUDO_USER; else REALUSER=$(whoami); fi
  _shadow="$((getent passwd $REALUSER) 2>&1)"
  if [ $? -eq 0 ]; then
    HOMEPATH="$(echo $_shadow | cut -d':' -f6)"
  else
    echo -e "\nUnable to retrieve $REALUSER's home directory. Manual install may be necessary."
    exit 1
  fi
}
  
############
### Functions to catch/display errors during execution
############

warn() {
  local fmt="$1"
  command shift 2>/dev/null
  echo -e "$fmt"
  echo -e "${@}"
  echo -e "\n*** ERROR ERROR ERROR ERROR ERROR ***"
  echo -e "-------------------------------------"
  echo -e "See above lines for error message."
  echo -e "Setup NOT completed.\n"
}

die () {
  local st="$?"
  warn "$@"
  exit "$st"
}

############
### Check network connection
###########

func_checknet() {
  echo -e "\nChecking for connection to GitHub."
  wget -q --spider "$GITURL"
  if [ $? -ne 0 ]; then
    echo -e "\n-----------------------------------------------------------------------------"
    echo -e "\nCould not connect to GitHub.  Please check your network and try again. A"
    echo -e "connection to GitHub is required to download the $PACKAGE packages."
    die
  else
    echo -e "\nConnection to GitHub ok."
  fi
}

############
### Check for free space
############

func_checkfree() {
  free_percentage=$(df /home | grep -vE '^Filesystem|tmpfs|cdrom|none' | awk '{ print $5 }')
  free=$(df /home | grep -vE '^Filesystem|tmpfs|cdrom|none' | awk '{ print $4 }')
  free_readable=$(df -H /home | grep -vE '^Filesystem|tmpfs|cdrom|none' | awk '{ print $4 }')
  
  if [ "$free" -le "524288" ]; then
    echo -e "Disk usage is $free_percentage, free disk space is $free_readable,"
    echo -e "\nNot enough space to continue setup. Installing BrewPi requires"
    echo -e "at least 512mb free space.\n"
    echo -e "Did you forget to expand your root partition? To do so run:"
    echo -e "sudo raspi-config\nExpand your root partition via the options, and reboot.\n"
    exit 1
  else
    echo -e "\nDisk usage is $free_percentage, free disk space is $free_readable."
  fi
}

############
### Choose a name for the chamber, set script path
############

func_getscriptpath() {
  regex="^0-9a-zA-Z\[-]_$"
  echo -e "\nIf you would like to use BrewPi in multi-chamber mode, or simply not use the"
  echo -e "defaults of /home/brewpi for scripts and /var/www/html for web pages, you may"
  echo -e "choose a sub directory now.  Any character entered that is not [A-Z], [a-z],"
  echo -e "[0-9], - or _ will be converted to an underscore.  Enter chamber name, or hit"
  read -p "enter to accept the defaults. [/home/brewpi]: " chamber < /dev/tty
  if [ -z "$chamber" ]; then
    scriptPath="/home/brewpi"
  else
    chamber="$(echo "$chamber" | sed -e 's/[^A-Za-z0-9._-]/_/g')"
    scriptPath="/home/brewpi/$chamber"
  fi
  echo -e "\nUsing $scriptPath for scripts directory."
}

############
### Install a udev rule to connect this instance to an Arduino
############

func_doport(){
  if [ -n $chamber ]; then
    echo -e "\nDEBUG: Chamber = $chamber."
    declare -i count=-1
    declare -a port
    declare -a serial
    declare -a manuf
    rules="/etc/udev/rules.d/99-arduino.rules"
    devices=$(ls /dev/ttyACM* /dev/ttyUSB* 2> /dev/null)
    # Get a list of USB TTY devices
    for device in $devices; do
      # Walk device tree | awk out the "paragraph" with the last device in chain 
      board=$(udevadm info --a -n $device | awk -v RS='' '/ATTRS{maxchild}=="0"/')
      if [ -n "$board" ]; then
          ((count++))
        # Get the device Product ID, Vendor ID and Serial Number
        #idProduct=$(echo "$board" | grep "idProduct" | cut -d'"' -f 2)
        #idVendor=$(echo "$board" | grep "idVendor" | cut -d'"' -f 2)
        port[count]="$device"
        serial[count]=$(echo "$board" | grep "serial" | cut -d'"' -f 2)
        manuf[count]=$(echo "$board" | grep "manufacturer" | cut -d'"' -f 2)
      fi
    done
    # Display a menu of devices to associate with this chamber
    if [ $count -gt -1 ]; then
      echo -e "\nThe following seem to be the Arduinos available on this system:\n"
      for (( c=0; c<=count; c++ ))
      do
        echo -e "[$c] Manuf: ${manuf[c]}, Serial: ${serial[c]}"
      done
      echo
      while :; do
        read -p "Please select an Arduino [0-$count] to associate with this chamber. [0]:  " board < /dev/tty
        [[ $board =~ ^[0-$count]+$ ]] || { echo "Please enter a valid choice."; continue; }
        if ((board >= 0 && board <= count)); then
          break
        fi
      done
    fi
    if [ -L "/dev/$chamber" ]; then
      echo "That name already exists as a /dev link, using it."
    else
      echo -e "\nCreating rule for board ${serial[board]} as /dev/$chamber."
      # Concatenate the rule
      rule='SUBSYSTEM=="tty", ATTRS{serial}=="sernum", SYMLINK+="chambr", '
      rule+='OWNER="root", GROUP="brewpi"'
      # Replace placeholders with real values
      rule="${rule/sernum/${serial[board]}}"
      rule="${rule/chambr/$chamber}"
      echo "$rule" >> "$rules"
    fi
    udevadm control --reload-rules
    udevadm trigger
  fi
}

############
### Stop all BrewPi processes
############

func_killproc() {
  if [ $(getent passwd brewpi) ]; then
   pidlist=$(pgrep -u brewpi)
  fi
  for pid in "$pidlist"
  do
    # Stop (kill) brewpi
    sudo touch /var/www/html/do_not_run_brewpi > /dev/null 2>&1
    if ps -p "$pid" > /dev/null 2>&1; then
      echo -e "\nAttempting gracefull shutdown of process $pid."
      sudo kill -15 "$pid"
      sleep 2
      if ps -p $pid > /dev/null 2>&1; then
        echo -e "\nTrying a little harder to terminate process $pid."
        sudo kill -2 "$pid"
        sleep 2
        if ps -p $pid > /dev/null 2>&1; then
          echo -e "\nBeing more forcefull with process $pid."
          sudo kill -1 "$pid"
          sleep 2
          while ps -p $pid > /dev/null 2>&1;
          do
            echo -e "\nBeing really insistent about killing process $pid now."
            echo -e "(I'm going to keep doing this till the process(es) are gone.)"
            sudo kill -9 "$pid"
            sleep 2
          done
        fi
      fi
    fi
  done
}

############
### Backup existing scripts directory
############

func_backupscript() {
  # Back up installpath if it has any files in it
  if [ -d "$scriptPath" ] && [ "$(ls -A ${scriptPath})" ]; then
    # Set place to put backups
    BACKUPDIR="$HOMEPATH/$GITPROJ-backup"
    # Stop (kill) brewpi
    sudo touch /var/www/html/do_not_run_brewpi
    func_killproc # Stop all BrewPi processes
    dirName="$BACKUPDIR/$(date +%F%k:%M:%S)-Script"
    echo -e "\nScript install directory is not empty, backing up this users home directory to"
    echo -e "'$dirName' and then deleting contents."
    mkdir -p "$dirName"
    cp -R "$scriptPath" "$dirName"/||die
    rm -rf "$scriptPath"/*||die
    find "$scriptPath"/ -name '.*' | xargs rm -rf||die
  fi
}

############
### Create/configure user account
############

func_makeuser() {
  if ! id -u brewpi >/dev/null 2>&1; then
    useradd -G dialout,sudo brewpi||die
    echo -e "\nPlease enter a password for the new user 'brewpi':" # TODO: Consider a locked/passwordless account
    until passwd brewpi < /dev/tty; do sleep 2; echo; done
  fi
  
  # Create install path if it does not exist
  if [ ! -d "$scriptPath" ]; then mkdir -p "$scriptPath"; fi
  chown -R brewpi:brewpi "$scriptPath"||die
}

############
### Clone BrewPi scripts
############

func_clonescripts() {
  echo -e "\nDownloading most recent BrewPi codebase."
  gitClone="sudo -u brewpi git clone $GITURLSCRIPT $scriptPath"
  eval $gitClone||die
}

############
### Install dependencies
############

func_dodepends() {
  chmod +x "$scriptPath/utils/doDepends.sh"
  eval "$scriptPath/utils/doDepends.sh"||die
}

############
### Web path setup
############

func_getwwwpath() {
  # TODO:  Can this be moved to func_makeuser()?
  # Add brewpi user to www-data and sudo group
  usermod -a -G www-data brewpi||warn
  # Add pi user to www-data group
  usermod -a -G www-data,brewpi pi||warn
  # Add www-data user to brewpi group (allow access to logs)
  usermod -a -G brewpi www-data||warn
  
  # Find web path based on Apache2 config
  echo -e "\nSearching for default web location."
  webPath="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* |xargs |cut -d " " -f2)"
  if [ -n "$webPath" ]; then
    echo -e "\nFound $webPath in /etc/apache2/sites-enabled/000-default*."
  else
    echo "Something went wrong searching for /etc/apache2/sites-enabled/000-default*."
    echo "Fix that and come back to try again."
    exit 1
  fi
  # Use chamber name if configured
  if [ -n "$chamber" ]; then
    webPath="webPath/$chamber"
  fi
  # Create web path if it does not exist
  if [ ! -d "$webPath" ]; then mkdir -p "$webPath"; fi
  chown -R www-data:www-data "$webPath"||die
  
  echo -e "\nUsing $webPath for scripts directory."
}

############
### Back up WWW path
############

func_backupwww() {
  # Back up webPath if it has any files in it
  sudo /etc/init.d/apache2 stop||die
  rm -rf "$webPath/do_not_run_brewpi" || true
  rm -rf "$webPath/index.html" || true
  if [ -d "$webPath" ] && [ "$(ls -A ${webPath})" ]; then
    dirName="$BACKUPDIR/$(date +%F%k:%M:%S)-WWW"
    echo -e "\nWeb directory is not empty, backing up the web directory to:"
    echo -e "'$dirName' and then deleting contents of web directory."
    mkdir -p "$dirName"
    cp -R "$webPath" "$dirName"/||die
    rm -rf "$webPath"/*||die
    find "$webPath"/ -name '.*' | xargs rm -rf||die
  fi
}

############
### Clone the web app
############

func_clonewww() {
  echo -e "\nCloning web site."
  gitClone="sudo -u www-data git clone $GITURLWWW $webPath"
  eval $gitClone||die
  # Keep BrewPi for running while we do this.
  touch "$webPath/do_not_run_brewpi"
}

###########
### If non-default paths are used, update config files accordingly
##########

func_updateconfig() {
  if [ -n "$chamber" ]; then
    echo -e "\nUsing non-default paths, updating config files."
    # Update brewpi scripts config
    echo "scriptPath = $scriptPath" >> "$scriptPath"/config.cfg
    # Update WWW page confog
    echo "<?php " >> "$webPath"/config_user.php
    echo "\$scriptPath = '$scriptPath';" >> "$webPath"/config_user.php
    # Update web path config
    echo "wwwPath = $webPath" >> "$scriptPath"/config.cfg
    # Update port setting
    echo "port = /dev/$chamber" >> "$scriptPath"/config.cfg
  fi
}

############
### Fix permissions
############

func_doperms() {
  chmod +x "$scriptPath/utils/doPerms.sh"
  eval "$scriptPath/utils/doPerms.sh"||die
}

############
### Install CRON job
############

func_docron() {
  touch "$webPath/do_not_run_brewpi" # make sure BrewPi does not start yet
  chmod +x "$scriptPath/utils/doCron.sh"
  eval "$scriptPath/utils/doCron.sh"||die
}

############
### Fix an issue with BrewPi and Safari-based browsers
############

func_fixsafari() {
  echo -e "\nFixing apache2.conf."
  sed -i -e 's/KeepAliveTimeout 5/KeepAliveTimeout 99/g' /etc/apache2/apache2.conf
  /etc/init.d/apache2 restart
}

############
### Flash controller
############

func_flash() {
  echo -e "\nIf you have previously flashed your controller, you do not need to do so again."
  read -p "Do you want to flash your controller now? [y/N]: " yn  < /dev/tty
  case $yn in
    [Yy]* ) eval "$scriptPath/utils/updateFirmware.py"||die ;;
    * ) ;;
  esac
}

############
### Print final banner
############

func_complete() {  
  localIP=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
  
  echo -e "\n                           BrewPi Install Complete"
  echo -e "------------------------------------------------------------------------------"
  echo -e "Review any uncaught errors above to be sure, but otherwise your initial"
  echo -e "install is complete."
  echo -e "\nBrewPi scripts will start shortly.  To view the BrewPi web interface, enter"
  echo -e "the following in your favorite browser:"
  # Use chamber name if configured
  if [ -n "$chamber" ]; then
    echo -e "http://$localIP/$chamber"
  else
    echo -e "http://$localIP"
  fi
  echo -e "http://$localIP"
  echo -e "\nIf you have Bonjour or another zeroconf utility installed, you may use this"
  echo -e "easier to remember address to access BrewPi without having to remembering an"
  echo -e "IP address:"
  # Use chamber name if configured
  if [ -n "$chamber" ]; then
    echo -e "http://$(hostname).local/$chamber"
  else
    echo -e "http://$(hostname).local"
  fi
  echo -e "\nUnder Windows, Bonjour installs with iTunes or can be downloaded separately at:"
  echo -e "https://support.apple.com/downloads/bonjour_for_windows"
  echo -e "\nHappy Brewing!"
}

############
### Main
############

func_main() {
  func_doinit # Initialize constants and variables
  echo -e "\nDEBUG: THISSCRIPT = $THISSCRPT, SCRIPTNAME = $SCRIPTNAME and basename = $(basename "$0")"
  func_arguments # Handle command line arguments
  func_checkroot # Make sure we are using sudo
  func_checknet # Check for connection to GitHub
  func_checkfree # Make sure there's enough free space for install
  func_getscriptpath # Choose a sub directory name or take default for scripts
  func_doport # Install a udev rule for the Arduino connected to this installation
  func_backupscript # Backup anything in the scripts directory
  func_makeuser # Create/configure user account
  func_clonescripts # Clone scripts git repository
  func_dodepends # Install dependencies
  func_getwwwpath # Get WWW install location
  func_backupwww # Backup anything in WWW location
  func_clonewww # Clone WWW files
  func_updateconfig # Update config files if non-default paths are used
  func_doperms # Set script and www permissions
  func_docron # Set up cron jobs
  func_fixsafari # Fix display bug with Safari browsers
  func_flash # Flash controller
  rm "$webPath/do_not_run_brewpi" # Allow BrewPi to start via cron
  func_complete # Cleanup and display instructions
}

############
### Start the script
############

echo -e "\n***Script $THISSCRIPT starting.***"

func_main # Run the script functions

exit 0
