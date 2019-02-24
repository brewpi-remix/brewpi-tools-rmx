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
  # Set up some project constants
  THISSCRIPT="$(basename $(realpath $0))"
  SCRIPTNAME="${THISSCRIPT%%.*}"
  SCRIPTPATH="$( cd $(dirname $0) ; pwd -P )"
  cd "$SCRIPTPATH"
  if [ -x "$(command -v git)" ] && [ -d .git ]; then
    VERSION="$(git describe --tags $(git rev-list --tags --max-count=1))"
    GITURL="$(git config --get remote.origin.url)"
    GITPROJ="$(basename $GITURL)"
    GITPROJ="${GITPROJ%.*}"
    PACKAGE="${GITPROJ^^}"
    GITBRNCH=$(git rev-parse --abbrev-ref HEAD)
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
    sudo -n true 2> /dev/null
    if [[ ${?} == "0" ]]; then
      echo -e "\nNot runing as root, relaunching correctly.\n"
      sleep 2
      eval "sudo bash $SCRIPTPATH/$THISSCRIPT $@"
      exit $?
    else
      # sudo not available, give instructions
      echo -e "\nThis script must be run as root: sudo $SCRIPTPATH/$THISSCRIPT $@" 1>&2
      exit 1
    fi
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
### Provide terminal escape codes
############

func_term() {
  tput colors > /dev/null 2>&1
  retval=$?
  if [ "$retval" == "0" ]; then
    BOLD=$(tput bold)   # Start bold text
    SMSO=$(tput smso)   # Start "standout" mode
    RMSO=$(tput rmso)   # End "standout" mode
    FGBLK=$(tput setaf 0)   # FG Black
    FGRED=$(tput setaf 1)   # FG Red
    FGGRN=$(tput setaf 2)   # FG Green
    FGYLW=$(tput setaf 3)   # FG Yellow
    FGBLU=$(tput setaf 4)   # FG Blue
    FGMAG=$(tput setaf 5)   # FG Magenta
    FGCYN=$(tput setaf 6)   # FG Cyan
    FGWHT=$(tput setaf 7)   # FG White
    FGRST=$(tput setaf 9)   # FG Reset to default color
    BGBLK=$(tput setab 0)   # BG Black
    BGRED=$(tput setab 1)   # BG Red
    BGGRN=$(tput setab 2)   # BG Green$(tput setaf $fg_color)
    BGYLW=$(tput setab 3)   # BG Yellow
    BGBLU=$(tput setab 4)   # BG Blue
    BGMAG=$(tput setab 5)   # BG Magenta
    BGCYN=$(tput setab 6)   # BG Cyan
    BGWHT=$(tput setab 7)   # BG White
    BGRST=$(tput setab 9)   # BG Reset to default color
    HHR=$(eval printf %.0s═ '{1..'"${COLUMNS:-$(tput cols)}"\}; echo)
    LHR=$(eval printf %.0s─ '{1..'"${COLUMNS:-$(tput cols)}"\}; echo)
    RESET=$(tput sgr0)  # FG/BG reset to default color
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
  echo -e "\nSee above lines for error message."
  echo -e "Setup NOT completed.\n"
}

die () {
  local st="$?"
  warn "$@"
  exit "$st"
}

############
### See if BrewPi is already installed
###########

func_findbrewpi() {
  declare home="/home/brewpi"
  instances=$(find "$home" -name "brewpi.py" 2> /dev/null)
  IFS=$'\n' instances=("$(sort <<<"${instances[*]}")") && unset IFS # Sort list
  if [ ${#instances} -eq 22 ]; then
    echo -e "\nFound BrewPi installed and configured to run in single instance mode.  To"
    echo -e "change to multi-chamber mode you must uninstall this instance configured as"
    echo -e "single-use and re-run the installer to configure multi-chamber."
    exit 1
  fi
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
  local req=512
  local freek=$(df -Pk | grep -m1 '\/$' | awk '{print $4}')
  local freem="$(expr $freek / 1024)"
  local freep=$(df -Pk | grep -m1 '\/$' | awk '{print $5}')

  if [ "$freem" -le "$req" ]; then
    echo -e "\nDisk usage is $freep, free disk space is $free MB,"
    echo -e "Not enough space to continue setup. Installing $PACKAGE requires"
    echo -e "at least $req MB free space."
    exit 1
  else
    echo -e "\nDisk usage is $freep, free disk space is $freem MB."
  fi
}

############
### Ensure chosen chamber name does not conflict with others
############

func_checkchamber() {
    local chamber="$1"
    local retval=0
    # Check /dev/$chamber
    if [ -L "/dev/$chamber" ]; then
      echo -e "\nA device with the name of /dev/$chamber already exists." > /dev/tty
      ((retval++))
    fi
    # Check /home/brewpi/$chamber
    if [ -d "/home/brewpi/$chamber" ]; then
      echo -e "\nA chamber with the name of /brewpi/$chamber already exists." > /dev/tty
      ((retval++))
    fi
    # Check /var/www/html/$chamber
    if [ -d "/var/www/html/$chamber" ]; then
      echo -e "\nA website with the name of /var/www/html/$chamber already exists." > /dev/tty
      ((retval++))
    fi
    # Check /etc/systemd/system/$chamber.service
    if [ -f "/etc/systemd/system/$chamber.service" ]; then
      echo -e "\nA daemon with the name of /etc/systemd/system/$chamber.service already exists." > /dev/tty
      ((retval++))
    fi
    # If we found a daemon, device, web or directory by that name, return false
    [ "$retval" -gt 0 ] && echo false || echo true
}

############
### Choose a name for the chamber & device, set script path
############

func_getscriptpath() {
  # See if we already have chambers installed
  if [ ! -z "$instances" ]; then
    # We've already got BrewPi installed in multi-chamber
    echo -e "\nThe following chambers are already configured on this Pi:\n"
    for instance in $instances
    do
      echo -e "\t$(dirname "${instance}")"
    done
    echo -e "\nWhat device/directory name would you like to use for this installation?  Any"
    echo -e "character entered that is not [a-z], [0-9], - or _ will be converted to an"
    echo -e "underscore.  Alpha characters will be converted to lowercase.  Do not enter a"
    echo -e "full path, enter the name to be appended to the standard paths.\n"
    read -p "Enter chamber name: " chamber < /dev/tty
    chamber="$(echo "$chamber" | sed -e 's/[^A-Za-z0-9._-]/_/g')"
    chamber="${chamber,,}"
    while [ -z "$chamber" ] || [ "$(func_checkchamber "$chamber")" == false ]
    do
      echo -e "\nError: Device/directory name blank or already exists."
      read -p "Enter chamber name: " chamber < /dev/tty
      chamber="$(echo "$chamber" | sed -e 's/[^A-Za-z0-9._-]/_/g')"
      chamber="${chamber,,}"
    done
    scriptPath="/home/brewpi/$chamber"
    echo -e "\nUsing $scriptPath for scripts directory."
  else
    # First install; give option to do multi-chamber
    echo -e "\nIf you would like to use BrewPi in multi-chamber mode, or simply not use the"
    echo -e "defaults for scripts and web pages, you may choose a name for sub directory and"
    echo -e "devices now.  Any character entered that is not [a-z], [0-9], - or _ will be"
    echo -e "converted to an underscore.  Alpha characters will be converted to lowercase."
    echo -e "Do not enter a full path, enter the name to be appended to the standard path.\n"
    echo -e "Enter device/directory name or hit enter to accept the defaults."
    read -p "[<Enter> = Single chamber only]:  " chamber < /dev/tty
    if [ -z "$chamber" ]; then
      scriptPath="/home/brewpi"
    else
      chamber="$(echo "$chamber" | sed -e 's/[^A-Za-z0-9._-]/_/g')"
      chamber="${chamber,,}"
      scriptPath="/home/brewpi/$chamber"
    fi
    echo -e "\nUsing $scriptPath for scripts directory."
  fi

  if [ ! -z $chamber ]; then
    echo -e "\nNow enter a friendly name to be used for the chamber as it will be displayed."
    echo -e "Capital letters may be used, however any character entered that is not [A-Z],"
    echo -e "[a-z], [0-9], - or _ will be replaced with an underscore. Spaces are allowed.\n"
    read -p "[<Enter> = $chamber]: " chamberName < /dev/tty
    if [ -z "$chamberName" ]; then
      chamberName="$chamber"
    else
      chamberName="$(echo "$chamberName" | sed -e 's/[^A-Za-z0-9._-\ ]/_/g')"
    fi
    echo -e "\nUsing $chamberName for chamber name."
  fi
}

############
### Install a udev rule to connect this instance to an Arduino
############

func_doport(){
  if [ ! -z $chamber ]; then
    declare -i count=-1
    declare -a port
    declare -a serial
    declare -a manuf
    rules="/etc/udev/rules.d/99-arduino.rules"
    devices=$(ls /dev/ttyACM* /dev/ttyUSB* 2> /dev/null)
    # Get a list of USB TTY devices
    for device in $devices; do
      declare ok=false
      # Walk device tree | awk out the stanza with the last device in chain
      board=$(udevadm info --a -n $device | awk -v RS='' '/ATTRS{maxchild}=="0"/')
      thisSerial=$(echo "$board" | grep "serial" | cut -d'"' -f 2)
      grep -q "$thisSerial" "$rules" 2> /dev/null || ok=true # Serial not in file
      [ -z "$board" ] && ok=false # Board exists
      if $ok; then
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
    if [ $count -gt 0 ]; then
      # There's more than one (it's 0-based)
      echo -e "\nThe following seem to be the Arduinos available on this system:\n"
      for (( c=0; c<=count; c++ ))
      do
        echo -e "[$c] Manuf: ${manuf[c]}, Serial: ${serial[c]}"
      done
      echo
      while :; do
        read -p "Please select an Arduino [0-$count] to associate with this chamber:  " board < /dev/tty
        [[ $board =~ ^[0-$count]+$ ]] || { echo "Please enter a valid choice."; continue; }
        if ((board >= 0 && board <= count)); then
          break
        fi
      done

      if [ -L "/dev/$chamber" ]; then
        echo -e "\nPort /dev/$chamber already exists as a link; using it but check your setup."
      else
        echo -e "\nCreating rule for board ${serial[board]} as /dev/$chamber."
        # Concatenate the rule
        rule='SUBSYSTEM=="tty", ATTRS{serial}=="sernum", SYMLINK+="chambr"'
        #rule+=', GROUP="brewpi"'
        # Replace placeholders with real values
        rule="${rule/sernum/${serial[board]}}"
        rule="${rule/chambr/$chamber}"
        echo "$rule" >> "$rules"
      fi
      udevadm control --reload-rules
      udevadm trigger
    elif [ $count -eq 0 ]; then
      # Only one (it's 0-based), use it
      if [ -L "/dev/$chamber" ]; then
        echo -e "\nPort /dev/$chamber already exists as a link; using it but check your setup."
      else
        echo -e "\nCreating rule for board ${serial[0]} as /dev/$chamber."
        # Concatenate the rule
        rule='SUBSYSTEM=="tty", ATTRS{serial}=="sernum", SYMLINK+="chambr"'
        #rule+=', GROUP="brewpi"'
        # Replace placeholders with real values
        rule="${rule/sernum/${serial[0]}}"
        rule="${rule/chambr/$chamber}"
        echo "$rule" >> "$rules"
      fi
      udevadm control --reload-rules
      udevadm trigger
    else
      # We have selected multichamber but there's no devices
      echo -e "\nYou've configured the system for multi-chamber support however no Arduinos were"
      echo -e "found to configure.  The following configuration file:"
      echo -e "$scriptPath/settings/config.cnf"
      echo -e "... will be set to use /dev/$chamber however you must configure your device"
      echo -e "manually in the $rules file."
      sleep 5
    fi
  else
    echo -e "\nScripts will use default 'port = auto' setting."
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
    touch /var/www/html/do_not_run_brewpi > /dev/null 2>&1
    if ps -p "$pid" > /dev/null 2>&1; then
      echo -e "\nAttempting graceful shutdown of process $pid."
      kill -15 "$pid"
      sleep 2
      if ps -p $pid > /dev/null 2>&1; then
        echo -e "\nTrying a little harder to terminate process $pid."
        kill -2 "$pid"
        sleep 2
        if ps -p $pid > /dev/null 2>&1; then
          echo -e "\nBeing more forceful with process $pid."
          kill -1 "$pid"
          sleep 2
          while ps -p $pid > /dev/null 2>&1;
          do
            echo -e "\nBeing really insistent about killing process $pid now."
            echo -e "(I'm going to keep doing this till the process(es) are gone.)"
            kill -9 "$pid"
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
    touch /var/www/html/do_not_run_brewpi
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
  echo -e "\nCreating and configuring accounts."
  if ! id -u brewpi >/dev/null 2>&1; then
    useradd brewpi -m -G dialout,sudo,www-data||die
  fi
  # Add current user to www-data & brewpi group
  usermod -a -G www-data,brewpi $SUDO_USER||die
}

############
### Clone BrewPi scripts
############

func_clonescripts() {
  # Clean out install path
  rm -fr "$scriptPath" >/dev/null 2>&1
  if [ ! -d "$scriptPath" ]; then mkdir -p "$scriptPath"; fi
  chown -R brewpi:brewpi "$scriptPath"||die
  echo -e "\nDownloading most recent BrewPi codebase."
  eval "sudo -u brewpi git clone -b $GITBRNCH --single-branch $GITURLSCRIPT $scriptPath"||die
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
  # Find web path based on Apache2 config
  echo -e "\nSearching for default web location."
  webPath="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* |xargs |cut -d " " -f2)"
  if [ ! -z "$webPath" ]; then
    echo -e "\nFound $webPath in /etc/apache2/sites-enabled/000-default*."
  else
    echo "Something went wrong searching for /etc/apache2/sites-enabled/000-default*."
    echo "Fix that and come back to try again."
    exit 1
  fi
  # Use chamber name if configured
  if [ ! -z "$chamber" ]; then
    webPath="$webPath/$chamber"
  fi
  # Create web path if it does not exist
  if [ ! -d "$webPath" ]; then mkdir -p "$webPath"; fi
  chown -R www-data:www-data "$webPath"||die

  echo -e "\nUsing $webPath for web directory."
}

############
### Back up WWW path
############

func_backupwww() {
  # Back up webPath if it has any files in it
  /etc/init.d/apache2 stop||die
  rm -rf "$webPath/do_not_run_brewpi" 2> /dev/null || true
  rm -rf "$webPath/index.html" 2> /dev/null || true
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
  eval "sudo -u www-data git clone -b $GITBRNCH --single-branch $GITURLWWW $webPath"||die
  # Keep BrewPi from running while we do things
  touch "$webPath/do_not_run_brewpi"
}

###########
### If non-default paths are used, create/update configuration files accordingly
##########

func_updateconfig() {
  if [ ! -z "$chamber" ]; then
    echo -e "\nCreating custom configurations for $chamber."
    # Create script path in custom script configuration file
    echo "scriptPath = $scriptPath" >> "$scriptPath/settings/config.cfg"
    # Create web path in custom script configuration file
    echo "wwwPath = $webPath" >> "$scriptPath/settings/config.cfg"
    # Create port name in custom script configuration file
    echo "port = /dev/$chamber" >> "$scriptPath/settings/config.cfg"
    # Create chamber name in custom script configuration file
    echo "chamber = \"$chamberName\"" >> "$scriptPath/settings/config.cfg"
    # Create script path in custom web configuration file
    echo "<?php " >> "$webPath"/config_user.php
    echo "\$scriptPath = '$scriptPath';" >> "$webPath/config_user.php"
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
### Install daemons
############

func_dodaemon() {
  touch "$webPath/do_not_run_brewpi" # make sure BrewPi does not start yet
  chmod +x "$scriptPath/utils/doDaemon.sh"
  eval "$scriptPath/utils/doDaemon.sh"||die
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
  case "$yn" in
    [Yy]* ) eval "python -u $scriptPath/utils/updateFirmware.py" ;;
    * ) ;;
  esac
}

############
### Print final banner
############

func_complete() {
  localIP=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
  echo -e "\n\n"
  echo -e "       ___         _        _ _    ___                _     _       "
  echo -e "      |_ _|_ _  __| |_ __ _| | |  / __|___ _ __  _ __| |___| |_ ___ "
  echo -e "       | || ' \(_-<  _/ _\` | | | | (__/ _ \ '  \| '_ \ / -_)  _/ -_)"
  echo -e "      |___|_||_/__/\__\__,_|_|_|  \___\___/_|_|_| .__/_\___|\__\___|"
  echo -e "                                                |_|                 "
  echo -e "\nBrewPi scripts will start shortly.  To view the BrewPi web interface, enter"
  echo -e "the following in your favorite browser:"
  # Use chamber name if configured
  if [ ! -z "$chamber" ]; then
    echo -e "http://$localIP/$chamber"
  else
    echo -e "http://$localIP"
  fi
  echo -e "\nIf you have Bonjour or another zeroconf utility installed, you may use this"
  echo -e "easier to remember address to access BrewPi:"
  # Use chamber name if configured
  if [ ! -z "$chamber" ]; then
    echo -e "http://$(hostname).local/$chamber"
  else
    echo -e "http://$(hostname).local"
  fi
  if [ -n "$chamber" ]; then
    echo -e "\nIf you would like to install another chamber, issue the command:"
    echo -e "sudo ~/brewpi-tools-rmx/install.sh"
    echo -e "\nYour multi-chamber web index is available at:"
    echo -e "http://$localIP - or -"
    echo -e "http://$(hostname).local"
  fi
  echo -e "\nHappy Brewing!"
}

############
### Main
############

main() {
  func_doinit # Initialize constants and variables
  func_arguments "$@" # Handle command line arguments
  exec > >(tee -ai "~/install.log")
  exec 2>&1
  func_checkroot "$@" # Make sure we are using sudo
  func_term # Provide term codes
  echo -e "\n***Script $THISSCRIPT starting.***"
  arg="${1//-}" # Strip out all dashes
  if [[ "$arg" == "q"* ]]; then quick=true; else quick=false; fi
  func_findbrewpi # See if BrewPi is already installed
  func_checknet # Check for connection to GitHub
  func_checkfree # Make sure there's enough free space for install
  func_getscriptpath # Choose a sub directory name or take default for scripts
  func_doport # Install a udev rule for the Arduino connected to this installation
  func_backupscript # Backup anything in the scripts directory
  func_makeuser # Create/configure user account
  func_clonescripts # Clone scripts git repository
  if [ ! "$quick" == "true" ]; then
    func_dodepends # Install dependencies
  fi
  func_getwwwpath # Get WWW install location
  func_backupwww # Backup anything in WWW location
  func_clonewww # Clone WWW files
  func_updateconfig # Update config files if non-default paths are used
  func_doperms # Set script and www permissions
  func_dodaemon # Set up daemons
  func_fixsafari # Fix display bug with Safari browsers
  # Add links for multi-chamber dashboard
  if [ -n "$chamber" ]; then
    webRoot="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* |xargs |cut -d " " -f2)"
    [ ! -L "$webRoot/index.php" ] && (eval "$scriptPath/utils/doIndex.sh"||warn)
  fi
  func_flash # Flash controller
  # Allow BrewPi to start via daemon
  rm "$webPath/do_not_run_brewpi" 2> /dev/null
  func_complete # Cleanup and display instructions
}

############
### Start the script
############

main "$@"
exit 0
