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
# Packages to be installed/checked via apt
APTPACKAGES="git arduino-core git-core pastebinit build-essential apache2 libapache2-mod-php php-cli php-common php-cgi php php-mbstring python-dev python-pip python-configobj"
# Packages to be installed/check via pip
PIPPACKAGES="pyserial psutil simplejson configobj gitpython"
# Website for network test
GITTEST="https://github.com"

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

### Check if we have root privs to run
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root: sudo ./$THISSCRIPT" 1>&2
   exit 1
fi

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
### Start the script
###########

echo -e "***Script $THISSCRIPT starting.***\n"

############
### Check for network connection
###########

echo -e "Checking for connection to GitHub.\n"
wget -q --spider "$GITTEST"
if [ $? -ne 0 ]; then
  echo -e "--------------------------------------------------------------------\n" \
          "Could not connect to GitHub.  Please check your network and try\n" \
          "again. A connection to GitHub is required to download the\n" \
          "$PACKAGE packages.\n"
  exit 1
else
  echo -e "Connection to GitHub ok.\n"
fi

############
### Install and update required packages
############

# Run 'apt update' if last run was > 1 week ago
lastUpdate=$(stat -c %Y /var/lib/apt/lists)
nowTime=$(date +%s)
if [ $(($nowTime - $lastUpdate)) -gt 604800 ] ; then
  echo -e "Last apt update was over a week ago. Running"
  echo -e "apt update before updating dependencies.\n"
  apt update||die
  echo
fi

# Now install any necessary packages if they are not installed
echo -e "Checking and installing required dependencies via apt."
for pkg in ${APTPACKAGES,,}; do
  pkgOk=$(dpkg-query -W --showformat='${Status}\n' ${pkg,,} | \
    grep "install ok installed")
  if [ -z "$pkgOk" ]; then
    echo -e "\nInstalling '$pkg'.\n"
    apt install ${pkg,,} -y||die
        echo
  fi
done

# Get list of installed packages with updates available
upgradesAvail=$(dpkg --get-selections | xargs apt-cache policy {} | \
  grep -1 Installed | sed -r 's/(:|Installed: |Candidate: )//' | \
  uniq -u | tac | sed '/--/I,+1 d' | tac | sed '$d' | sed -n 1~2p)

# Loop through the required packages and see if they need an upgrade
for pkg in ${APTPACKAGES,,}; do
  if [[ ${upgradesAvail,,} == *"$pkg"* ]]; then
    echo -e "\nUpgrading '$pkg'.\n"
    apt upgrade ${pkg,,} -y||die
  fi
done

# Cleanup
echo -e "\nCleaning up local repositories."
apt clean -y||die
apt autoclean -y||die
apt autoremove --purge -y||die

# Install any Python packages not installed, update those installed
echo -e "\nChecking and installing required dependencies via pip."
pipcmd='pipInstalled=$(pip list --format=legacy)'
eval "$pipcmd"
pipcmd='pipInstalled=$(echo "$pipInstalled" | cut -f1 -d" ")'
eval "$pipcmd"
for pkg in ${PIPPACKAGES,,}; do
  if [[ ! ${pipInstalled,,} == *"$pkg"* ]]; then
    echo -e "Installing '$pkg'."
    pip install $pkg||die
  else
    echo -e "Checking for update to '$pkg'."
    pip install $pkg --upgrade||die
  fi
done

echo -e "\nDone processing BrewPi dependencies.\n"

