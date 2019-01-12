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

############
### Init
############

# Set up some project variables
THISSCRIPT=$(basename "$0")
VERSION="0.4.0.0"
# These should stay the same
GITUSER="lbussy"
PACKAGE="BrewPi-Tools-RMX"
GITPROJ=${PACKAGE,,}
GITPROJWWW="brewpi-www-rmx"
GITPROJSCRIPT="brewpi-script-rmx"
GITHUB="https://github.com"
SCRIPTNAME="${THISSCRIPT%%.*}"
# Concatenate URLs
GITHUBWWW="$GITHUB/$GITUSER/$GITPROJWWW.git"
GITHUBSCRIPT="$GITHUB/$GITUSER/$GITPROJSCRIPT.git"
# Website for network test
GITTEST=$GITHUBWWW
# Hold return values
declare -i retval=0

# Support the standard --help and --version.
#
# func_usage outputs to stdout the --help usage message.
func_usage () {
  echo -e "$PACKAGE $THISSCRIPT version $VERSION
Usage: sudo . $THISSCRIPT    {run as user 'pi'}"
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
### Make sure user pi is running with sudo
############

if [ $SUDO_USER ]; then REALUSER=$SUDO_USER; else REALUSER=$(whoami); fi
if [[ $EUID -ne 0 ]]; then UIDERROR="root";
elif [[ $REALUSER != "pi" ]]; then UIDERROR="pi"; fi
if [[ ! $UIDERROR == ""  ]]; then
  echo -e "This script must be run by user 'pi' with sudo:"
  echo -e "sudo . $THISSCRIPT\n" 1>&2
  exit 1
fi
# And get the user home directory
_shadow="$((getent passwd $REALUSER) 2>&1)"
if [ $? -eq 0 ]; then
  homepath="$(echo $_shadow | cut -d':' -f6)"
else
  echo "Unable to retrieve $REALUSER's home directory. Manual install"
  echo "may be necessary."
  exit 1
fi

############
### Start the script
############

echo -e "\n***Script $THISSCRIPT starting.***\n"

############
### Functions to catch/display errors during setup
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
### Check for network connection
###########

echo -e "Checking for connection to GitHub.\n"
wget -q --spider "$GITTEST"
if [ $? -ne 0 ]; then
  echo -e "-------------------------------------------------------------\n" \
          "Could not connect to GitHub.  Please check your network and " \
                  "try again. A connection to GitHub is required to download the" \
                  "$PACKAGE package.\n"
  exit 1
else
  echo -e "Connection to GitHub ok.\n"
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
echo -e "Installing application in $installPath.\n"

############
### Clean out old cron
############

if [ -f /etc/cron.d/brewpi ]; then
  rm /etc/cron.d/brewpi
  /etc/init.d/cron restart
  echo
fi

############
### Web path setup
############

# Find web path based on Apache2 config
echo -e "Searching for default web location."
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

# Set place to put backups
BACKUPDIR="$homepath/$GITPROJ-backup"

# Back up installpath if it has any files in it
if [ -d "$installPath" ] && [ "$(ls -A ${installPath})" ]; then
  # Stop BrewPi if it's running
  if [ $(ps -ef | grep brewpi.py | grep -v grep) ]; then
    touch "$webPath/do_not_run_brewpi"
    $installPath/brewpi.py --quit
    $installPath/brewpi.py --kill
    kill -9 $(pidof brewpi.py)
  fi
  dirName="$BACKUPDIR/$(date +%F%k:%M:%S)-Script"
  echo -e "\nScript install directory is not empty, backing up this users home directory to"
  echo -e "$dirName"
  echo -e "and then deleting contents of install directory.\n"
  mkdir -p "$dirName"
  cp -R "$installPath" "$dirName"/||die
  rm -rf "$installPath"/*||die
  find "$installPath"/ -name '.*' | xargs rm -rf||die
fi

# Back up webPath if it has any files in it
sudo /etc/init.d/apache2 stop||die
rm -rf "$webPath/do_not_run_brewpi" || true
rm -rf "$webPath/index.html" || true
if [ -d "$webPath" ] && [ "$(ls -A ${webPath})" ]; then
  dirName="$BACKUPDIR/$(date +%F%k:%M:%S)-WWW"
  echo -e "\nWeb directory is not empty, backing up the web directory to:"
  echo -e "$dirName"
  echo -e "and then deleting contents of web directory.\n"
  mkdir -p "$dirName"
  cp -R "$webPath" "$dirName"/||die
  rm -rf "$webPath"/*||die
  find "$webPath"/ -name '.*' | xargs rm -rf||die
fi

############
### Create/configure user accounts and directories
############

if ! id -u brewpi >/dev/null 2>&1; then
  useradd -G www-data,dialout brewpi||die
  echo -e "\nPlease enter a password for the new user 'brewpi':"
  until passwd brewpi < /dev/tty; do sleep 2; echo; done
fi
# add pi user to brewpi and www-data group
usermod -a -G www-data pi||die
usermod -a -G brewpi pi||die

# Create install and web path if it does not exist
if [ ! -d "$installPath" ]; then mkdir -p "$installPath"; fi
if [ ! -d "$webPath" ]; then mkdir -p "$webPath"; fi

chown -R www-data:www-data "$webPath"||die
chown -R brewpi:brewpi "$installPath"||die

############
### Now for the install
############

# Clone BrewPi repositories
echo -e "\nDownloading most recent BrewPi codebase."
echo -e "\nCloning scripts."
gitClone="sudo -u brewpi git clone $GITHUBSCRIPT $installPath"
eval $gitClone||die
echo -e "\nCloning web site."
gitClone="sudo -u www-data git clone $GITHUBWWW $webPath"
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
### Install dependencies
############

eval "$installPath/utils/doDepends.sh"||die

############
### Fix permisions
############

eval "$installPath/utils/doPerms.sh"||die

############
### Install CRON job
############

eval "$installPath/utils/doCron.sh"||die

############
### Fix an issue with BrewPi and Safari-based browsers
############

echo -e "\nFixing apache2.conf."
sed -i -e 's/KeepAliveTimeout 5/KeepAliveTimeout 99/g' /etc/apache2/apache2.conf
/etc/init.d/apache2 restart

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

# Allw BrewPi to start via cron.
touch "$webPath/do_not_run_brewpi"

echo -e "\nDone installing BrewPi."

echo -e "\n* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
echo -e "Review the output above for any errors, otherwise, your initial"
echo -e "install is complete.\n"
echo -e "To view your BrewPi web interface, enter http://$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p') into your"
echo -e "web browser.\n"
echo -e "If you have Bonjour installed (in Windows, it installs with iTunes) you can"
echo -e "take advantage of zeroconf and use the address http://$(hostname).local"
echo -e "instead.\n"
echo -e "Happy Brewing!\n"

exit 0

