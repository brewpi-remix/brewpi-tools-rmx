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

# Set up some project variables
THISSCRIPT=$(basename "$0")
VERSION="0.4.0.0"
# These should stay the same
PACKAGE="BrewPi-Tools-RMX"
GITPROJ=${PACKAGE,,}
SCRIPTNAME="${THISSCRIPT%%.*}"

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

# Get the user home directory
_shadow="$((getent passwd $REALUSER) 2>&1)"
if [ $? -eq 0 ]; then
  homepath="$(echo $_shadow | cut -d':' -f6)"
else
  echo "Unable to retrieve $REALUSER's home directory. Manual install"
  echo "may be necessary."
  exit 1
fi

# Change directory to where the script is
unset CDPATH
myPath="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
cd "$myPath"

# Make sure git is installed
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' git|grep "install ok installed")
if [ "" == "$PKG_OK" ]; then
  echo "Error:  No git found."
  exit 1
else
  # See if we can get the active branch
  active_branch=$(git symbolic-ref -q HEAD)
  if [ $? -eq 0 ]; then
    active_branch=${active_branch##refs/heads/}

    # Check local against remote
    git fetch
    changes=$(git log HEAD..origin/"$active_branch" --oneline)

    if [ -z "$changes" ]; then
    	# no changes
    	echo "$myPath is up to date."
    	exit 0
    fi

    echo "$myPath is not up to date, updating from GitHub."
    git pull;
    if [ $? -ne 0 ]; then
      # Not able to make a pull because of changed local files
      echo -e "\nAn error occurred during git pull. Please update $myPath"
      echo -e "manually.  You can stash your local changes and then pull with:"
      echo -e "cd $myPath; sudo git stash; sudo git pull\n"
      echo -e "Under normal conditions you should never see this message.  If"
      echo -e "you have no idea what is going on, restarting the entire process"
      echo -e "should reset things to normal.\n"
      exit 1
    fi
    cd - # Go back where we started
  else
    # No local repository found
    exit 1
  fi
fi

