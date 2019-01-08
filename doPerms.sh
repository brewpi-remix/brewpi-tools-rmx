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
PACKAGE="BrewPi-Tools-RMX"

# Support the standard --help and --version.
#
# func_usage outputs to stdout the --help usage message.
func_usage () {
  echo -e "$PACKAGE $THISSCRIPT version $VERSION
Usage: sudo . $THISSCRIPT"
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

############
### Start the script
############
echo -e "\n***Script $THISSCRIPT starting.***"

############
### Functions to catch/display errors during setup
############
warn() {
  local fmt="$1"
  command shift 2>/dev/null
  echo "$fmt"
  echo "${@}"
  echo
  echo "*** ERROR ERROR ERROR ERROR ERROR ***"
  echo "-------------------------------------"
  echo "See above lines for error message."
  echo "Script did not complete."
  echo
}

die () {
  local st="$?"
  warn "$@"
  exit "$st"
}

############
### Get some directories
############

# Get the pi user's home directory
_shadow="$((getent passwd $REALUSER) 2>&1)"
if [ $? -eq 0 ]; then
  homepath="$(echo $_shadow | cut -d':' -f6)"
else
  echo "Unable to retrieve $REALUSER's home directory. Manual install"
  echo "may be necessary."
  exit 1
fi

# Get the brewpi user's home directory
_shadow="$((getent passwd brewpi) 2>&1)"
if [ $? -eq 0 ]; then
  scriptPath="$(echo $_shadow | cut -d':' -f6)"
else
  echo "Unable to retrieve brewpi's home directory. Manual install"
  echo "may be necessary."
  exit 1
fi

# Find web path based on Apache2 config
webPath="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* |xargs |cut -d " " -f2)"
if [ "$webPath" == "" ]; then
  echo "Unable to retrieve html path. Manual install"
  echo "may be necessary."
  exit 1
fi

############
### Fix permissions
############

echo -e "\nFixing file permissions for $webPath."
chown -R www-data:www-data "$webPath"||warn
chmod -R g+rwx "$webPath"||warn
find "$webPath" -type d -exec chmod g+rwxs {} \;||warn

echo -e "\nFixing file permissions for $scriptPath."
chown -R brewpi:brewpi "$scriptPath"||warn
chmod -R g+rwx "$scriptPath"||warn
find "$scriptPath" -type d -exec chmod g+rwxs {} \;||warn

