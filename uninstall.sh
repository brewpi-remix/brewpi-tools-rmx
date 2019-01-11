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

# Packages to be installed/checked via apt
APTPACKAGES="git arduino-core git-core pastebinit build-essential apache2 libapache2-mod-php php-cli php-common php-cgi php php-mbstring python-dev python-pip python-configobj php-xml"
# Packages to be installed/check via pip
PIPPACKAGES="pyserial psutil simplejson configobj gitpython"

echo -e "\nBeginning BrewPi uninstall."

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
### Remove all BrePi Packages
############

# Remove all BrewPi Installation items
# (except for installed apt/pip packages)
cd ~ # Start from home

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
if [ -f /home/pi/bootstrap.log ]; then
  echo -e "\nDeleting /home/pi/bootstrap.log."
  sudo rm -f /home/pi/bootstrap.log
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

if getent group brewpi | grep &>/dev/null "\b${pi}\b"; then
  echo -e "\nRemoving pi from brewpi group."
  sudo deluser pi brewpi
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
        echo -e "Removing '$pkg'."
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
echo -e "\nCleaning up local repositories."
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

echo -e "\nUninstall complete."

