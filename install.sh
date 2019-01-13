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

# Change to current dir so we can get the git info
cd "$(dirname "$0")"

# Set up some project constants
THISSCRIPT="$(basename "$0")"
SCRIPTNAME="${THISSCRIPT%%.*}"
VERSION="$(git describe --tags $(git rev-list --tags --max-count=1))"
GITURL="$(git config --get remote.origin.url)"
GITPROJ="$(basename $GITURL)" && GITPROJ="${GITPROJ%.*}"
PACKAGE="${GITPROJ^^}"
GITPROJWWW="brewpi-www-rmx"
GITPROJSCRIPT="brewpi-script-rmx"
# Concatenate URLs
GITURLWWW="${GITURL/$GITPROJ/$GITPROJWWW}"
GITURLSCRIPT="${GITURL/$GITPROJ/$GITPROJSCRIPT}"

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
if test $# = 1; then
  case "$1" in
    --help | --hel | --he | --h )
      func_usage; exit 0 ;;
    --version | --versio | --versi | --vers | --ver | --ve | --v )
      func_version; exit 0 ;;
  esac
fi

############
### Check privilges and permissions
############

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
### Start the script
############

echo -e "\n***Script $THISSCRIPT starting.***"

############
### Check network connection
###########

echo -e "\nChecking for connection to GitHub."
wget -q --spider "$GITURL"
if [ $? -ne 0 ]; then
  echo -e "\n-----------------------------------------------------------------------------"
  echo -e "\nCould not connect to GitHub.  Please check your network and try again. A"
  echo -e "\nconnection to GitHub is required to download the $PACKAGE packages."
  die
else
  echo -e "\nConnection to GitHub ok."
fi

############
### Check for free space
############

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
  echo -e "Disk usage is $free_percentage, free disk space is $free_readable.\n"
fi

############
### Install path setup
############

echo -e "Any data in the following location will be backed up during install."
read -p "Where would you like to install BrewPi? [/home/brewpi]: " installPath < /dev/tty
if [ -z "$installPath" ]; then
  installPath="/home/brewpi"
else
  case "$installPath" in
    y | Y | yes | YES| Yes )
      installPath="/home/brewpi";; # accept default when y/yes is answered
    * )
      ;;
  esac
fi
echo -e "\nInstalling application in $installPath."

# Set place to put backups
BACKUPDIR="$HOMEPATH/$GITPROJ-backup"

# Back up installpath if it has any files in it
if [ -d "$installPath" ] && [ "$(ls -A ${installPath})" ]; then
  # Stop (kill) brewpi
  sudo touch /var/www/html/do_not_run_brewpi
  if pgrep -u brewpi >/dev/null 2>&1; then
    echo -e "\nAttempting gracefull shutdown of process(es) $(pgrep -u brewpi)."
    cmd="sudo kill -15 $(pgrep -u brewpi)"
    eval $cmd
    sleep 2
    if pgrep -u brewpi >/dev/null 2>&1; then
      echo -e "Trying a little harder to terminate process(es) $(pgrep -u brewpi)."
      cmd="sudo kill -2 $(pgrep -u brewpi)"
      eval $cmd
      sleep 2
      if pgrep -u brewpi >/dev/null 2>&1; then
        echo -e "Being more forcefull with process(es) $(pgrep -u brewpi)."
        cmd="sudo kill -1 $(pgrep -u brewpi)"
        eval $cmd
        sleep 2
        while pgrep -u brewpi >/dev/null 2>&1;
        do
          echo -e "Being really insistent about killing process(es) $(pgrep -u brewpi) now."
          echo -e "(I'm going to keep doing this till the process(es) are gone.)"
          cmd="sudo kill -9 $(pgrep -u brewpi)"
          eval $cmd
          sleep 2
        done
      fi
    fi
  fi
  dirName="$BACKUPDIR/$(date +%F%k:%M:%S)-Script"
  echo -e "\nScript install directory is not empty, backing up this users home directory to"
  echo -e "'$dirName' and then deleting"
  echo -e "contents of install directory."
  mkdir -p "$dirName"
  cp -R "$installPath" "$dirName"/||die
  rm -rf "$installPath"/*||die
  find "$installPath"/ -name '.*' | xargs rm -rf||die
fi

############
### Create/configure user account
############

if ! id -u brewpi >/dev/null 2>&1; then
  useradd -G dialout brewpi||die
  echo -e "\nPlease enter a password for the new user 'brewpi':"
  until passwd brewpi < /dev/tty; do sleep 2; echo; done
fi

# Create install path if it does not exist
if [ ! -d "$installPath" ]; then mkdir -p "$installPath"; fi
chown -R brewpi:brewpi "$installPath"||die

############
### Clone BrewPi scripts
############

echo -e "\nDownloading most recent BrewPi codebase."
echo -e "\nCloning scripts."
gitClone="sudo -u brewpi git clone $GITURLSCRIPT $installPath"
eval $gitClone||die

############
### Install dependencies
############

chmod +x "$installPath/utils/doDepends.sh"
eval "$installPath/utils/doDepends.sh"||die

############
### Web path setup
############

# Add brewpi user to www-data group
usermod -a -G www-data brewpi||warn
# add pi user to www-data group
usermod -a -G www-data,brewpi pi||warn
# Find web path based on Apache2 config
echo -e "\nSearching for default web location."
webPath="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* |xargs |cut -d " " -f2)"
if [ ! -z "$webPath" ]; then
  echo "Found $webPath in /etc/apache2/sites-enabled/000-default*."
else
  echo "Something went wrong searching for /etc/apache2/sites-enabled/000-default*."
  echo "Fix that and come back to try again."
  exit 1
fi

# Get WWW install path
echo -e "\nAny data in the following location will be backed up during install."
read -p "To where would you like to copy the BrewPi web files? [$webPath]: " webPathInput < /dev/tty
if [ -z "$webPathInput" ]; then
  webPathInput="$webPath"
else
  case "$webPathInput" in
    y | Y | yes | YES| Yes )
      webPathInput="$webPath";; # accept default when y/yes is answered
    * )
      ;;
  esac
fi
webPath="$webPathInput"
echo -e "\nInstalling web files in $webPath.\n"

# Create web path if it does not exist
if [ ! -d "$webPath" ]; then mkdir -p "$webPath"; fi
chown -R www-data:www-data "$webPath"||die

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

############
### Clone the web app
############

echo -e "\nCloning web site."
gitClone="sudo -u www-data git clone $GITURLWWW $webPath"
eval $gitClone||die
# Keep BrewPi for running while we do this.
touch "$webPath/do_not_run_brewpi"

###########
### If non-default paths are used, update config files accordingly
##########

if [[ "$installPath" != "/home/brewpi" ]]; then
  echo -e "\nUsing non-default path for the script dir, updating config files.\n"
  echo "scriptPath = $installPath" >> "$installPath"/settings/config.cfg

  echo "<?php " >> "$webPath"/config_user.php
  echo "\$scriptPath = '$installPath';" >> "$webPath"/config_user.php
fi

if [[ "$webPath" != "$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* |xargs |cut -d " " -f2)" ]]; then
  echo -e "\nUsing non-default path for the web dir, updating config files.\n"
  echo "wwwPath = $webPath" >> "$installPath"/settings/config.cfg
fi

############
### Fix permisions
############

chmod +x "$installPath/utils/doPerms.sh"
eval "$installPath/utils/doPerms.sh"||die

############
### Install CRON job
############

touch "$webPath/do_not_run_brewpi" # make sure BrewPi does not start yet
chmod +x "$installPath/utils/doCron.sh"
eval "$installPath/utils/doCron.sh"||die

############
### Fix an issue with BrewPi and Safari-based browsers
############

echo -e "\nFixing apache2.conf."
sed -i -e 's/KeepAliveTimeout 5/KeepAliveTimeout 99/g' /etc/apache2/apache2.conf
/etc/init.d/apache2 restart

############
### Create sym links to BrewPi and Updater
############

ln -sf "$installPath/brewpi.py" "$HOMEPATH/$GITPROJ/"
ln -sf "$installPath/utils/updater.py" "$HOMEPATH/$GITPROJ/"

############
### Flash controller
############

echo -e "\nIf you have previously flashed your controller, you do not need to do so again."
read -p "Do you want to flash your controller now? [y/N]: " yn  < /dev/tty
case $yn in
  [Yy]* ) eval "$installPath/utils/updateFirmware.py"||die ;;
  * ) ;;
esac

############
### Done
############

# Allow BrewPi to start via cron.
rm "$webPath/do_not_run_brewpi"

localIP=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')

echo -e "\n                           BrewPi Install Complete"
echo -e "------------------------------------------------------------------------------"
echo -e "Review any uncaught errors above to be sure, but otherwise your initial"
echo -e "install is complete."
echo -e "\nLinks to two important tools: brewpi.py and updater.py, have been created in"
echo -e "$HOMEPATH$GITPROJ/ for ease of use."
echo -e "\nBrewPi scripts will start shortly.  To view the BrewPi web interface, enter"
echo -e "the following in your favorite browser:"
echo -e "http://$localIP"
echo -e "\nIf you have Bonjour or another zeroconf utility installed, you may use this"
echo -e "easier to remember address to access BrewPi without having to remembering an"
echo -e "IP address:"
echo -e "http://$(hostname).local "
echo -e "\nUnder Windows, Bonjour installs with iTunes or can be downloaded separately at:"
echo -e "\nhttps://support.apple.com/downloads/bonjour_for_windows"
echo -e "\nHappy Brewing!"

exit 0

