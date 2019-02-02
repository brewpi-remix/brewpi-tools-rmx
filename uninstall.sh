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

# Packages to be uninstalled via apt
APTPACKAGES="git-core pastebinit build-essential git arduino-core libapache2-mod-php apache2 python-configobj python-dev python-pip php-xml php-mbstring php-cgi php-cli php-common php"
# Packages to be uninstalled via pip
PIPPACKAGES="pyserial psutil simplejson gitpython configobj"

echo -e "\nBeginning BrewPi uninstall."

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

############
### Start the script
############

echo -e "\n***Script $THISSCRIPT starting.***"

############
### Cleanup cron
############

# Clear out the old brewpi cron if it exists
if [ -f /etc/cron.d/brewpi ]; then
  echo -e "\nResetting cron."
  sudo rm -f /etc/cron.d/brewpi
  sudo /etc/init.d/cron restart
fi

############
### Remove all BrewPi Packages
############

cd .. # Start from home

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

# Wipe out all the directories
if [ -d /home/pi/brewpi-tools-rmx ]; then
  echo -e "\nClearing /home/pi/brewpi-tools-rmx."
  sudo rm -fr /home/pi/brewpi-tools-rmx
fi
if [ -d /home/brewpi ]; then
  echo -e "\nClearing /home/brewpi."
  sudo rm -fr /home/brewpi
fi
# Wipe out www if it exists and is not empty
if [ -d /var/www/html ]; then
  if [ ! -z "$(ls -A /var/www/html)" ]; then
    echo -e "\nClearing /var/www/html."
    sudo rm -fr /var/www/html
	# Re-create html durectory
    sudo mkdir /var/www/html
    sudo chown www-data:www-data /var/www/html
  fi
fi

############
### Remove brewpi user/group
############

username="pi"
if getent group brewpi | grep &>/dev/null "\b${username}\b"; then
  echo -e "\nRemoving pi from brewpi group."
  sudo deluser pi brewpi
fi
if getent group www-data | grep &>/dev/null "\b${username}\b"; then
  echo -e "\nRemoving pi from www-data group."
  sudo deluser pi www-data
fi
username="www-data"
if getent group brewpi | grep &>/dev/null "\b${username}\b"; then
  echo -e "\nRemoving www-data from brewpi group."
  sudo deluser www-data brewpi
fi
username="brewpi"
if getent group www-data | grep &>/dev/null "\b${username}\b"; then
  echo -e "\nRemoving pi from www-data group."
  sudo deluser brewpi www-data
fi
if sudo id "brewpi" > /dev/null 2>&1; then
  echo -e "\nRemoving user brewpi."
  sudo userdel brewpi
fi

############
### Reset Apache
############

# Reset Apache config to stock
if [ -f /etc/apache2/apache2.conf ]; then
  if grep -qF "KeepAliveTimeout 99" /etc/apache2/apache2.conf; then
    echo -e "\nResetting /etc/apache2/apache2.conf."
    sudo sed -i -e 's/KeepAliveTimeout 99/KeepAliveTimeout 5/g' /etc/apache2/apache2.conf
    sudo /etc/init.d/apache2 restart
  fi
fi

############
### Remove pip packages
############

echo -e "\nChecking for pip packages installed with BrewPi."
if pip &>/dev/null; then
  pipInstalled=$(sudo pip list --format=legacy)
  if [ $? -eq 0 ]; then
    pipInstalled=$(echo "$pipInstalled" | awk '{ print $1 }')
    for pkg in ${PIPPACKAGES,,}; do
      if [[ ${pipInstalled,,} == *"$pkg"* ]]; then
        echo -e "\nRemoving '$pkg'.\n"
        sudo pip uninstall $pkg -y
      fi
    done
  fi
fi

############
### Remove apt packages
############

echo -e "\nChecking for apt packages installed with BrewPi."
# Get list of installed packages
packagesInstalled=$(sudo dpkg --get-selections | awk '{ print $1 }')
# Loop through the required packages and uninstall those in $APTPACKAGES
for pkg in ${APTPACKAGES,,}; do
  if [[ ${packagesInstalled,,} == *"$pkg"* ]]; then
    echo -e "\nRemoving '$pkg'.\n"
	sudo apt remove --purge $pkg -y
  fi
done

############
### Cleanup repos
############

# Cleanup
echo -e "Cleaning up local repositories."
sudo apt clean -y
sudo apt autoclean -y
sudo apt autoremove --purge -y

############
### Change hostname
###########

oldHostName=$(hostname)
newHostName="raspberrypi"
echo -e "\nResetting hostname."
if [ "$oldHostName" != "$newHostName" ]; then
  sed1="sudo sed -i 's/$oldHostName/$newHostName/g' /etc/hosts"
  sed2="sudo sed -i 's/$oldHostName/$newHostName/g' /etc/hostname"
  eval $sed1
  eval $sed2
  sudo hostnamectl set-hostname $newHostName
  sudo /etc/init.d/avahi-daemon restart
  echo -e "\nYour hostname has been changed back to '$newHostName'.\n"
  echo -e "(If your hostname is part of your prompt, your prompt will"
  echo -e "not change untill you log out and in again.  This will have"
  echo -e "no effect on anything but the way the prompt looks.)"
  sleep 3
fi

############
### Reset password
###########

echo -e "\nResetting password for 'pi' back to 'raspberry'."
echo "pi:raspberry" | sudo chpasswd

############
### Work Complete
###########

echo -e "\n***Script $THISSCRIPT complete.***"

exit 0
