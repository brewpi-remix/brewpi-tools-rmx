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
VERSION="$(git describe --tags $(git rev-list --tags --max-count=1))" > /dev/null 2>&1
GITURL="$(git config --get remote.origin.url)" > /dev/null 2>&1
GITPROJ="$(basename $GITURL)" && GITPROJ="${GITPROJ%.*}" > /dev/null 2>&1
PACKAGE="${GITPROJ^^}" > /dev/null 2>&1

# Packages to be uninstalled via apt
APTPACKAGES="git-core pastebinit build-essential git arduino-core libapache2-mod-php apache2 python-configobj python-dev python-pip php-xml php-mbstring php-cgi php-cli php-common php"
# nginx packages to be uninstalled via apt if present
NGINXPACKAGES="libgd-tools, fcgiwrap, nginx-doc, ssl-cert, fontconfig-config, fonts-dejavu-core, libfontconfig1, libgd3, libjbig0, libnginx-mod-http-auth-pam, libnginx-mod-http-dav-ext, libnginx-mod-http-echo, libnginx-mod-http-geoip, libnginx-mod-http-image-filter, libnginx-mod-http-subs-filter, libnginx-mod-http-upstream-fair, libnginx-mod-http-xslt-filter, libnginx-mod-mail, libnginx-mod-stream, libtiff5, libwebp6, libxpm4, libxslt1.1, nginx, nginx-common, nginx-full"
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
cd ~ # Start from home

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
### Stop all BrewPi processes
############

pidlist=$(pgrep -u brewpi)  > /dev/null 2>&1
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

############
### Remove all BrewPi Packages
############

# Wipe out tools
if [ -d /home/pi/brewpi-tools-rmx ]; then
  echo -e "\nClearing /home/pi/brewpi-tools-rmx."
  sudo rm -fr /home/pi/brewpi-tools-rmx
fi
# Wipe out legacy tools
if [ -d /home/pi/brewpi-tools ]; then
  echo -e "\nClearing /home/pi/brewpi-tools."
  sudo rm -fr /home/pi/brewpi-tools
fi
# Wipe out BrewPi scripts
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
  echo -e "\nRemoving $username from brewpi group."
  sudo deluser pi brewpi
fi
if getent group www-data | grep &>/dev/null "\b${username}\b"; then
  echo -e "\nRemoving $username from www-data group."
  sudo deluser pi www-data
fi
username="www-data"
if getent group brewpi | grep &>/dev/null "\b${username}\b"; then
  echo -e "\nRemoving $username from brewpi group."
  sudo deluser www-data brewpi
fi
username="brewpi"
if getent group www-data | grep &>/dev/null "\b${username}\b"; then
  echo -e "\nRemoving $username from www-data group."
  sudo deluser brewpi www-data
fi
if sudo id "$username" > /dev/null 2>&1; then
  echo -e "\nRemoving user $username."
  sudo userdel "$username"
fi
egrep -i "^$username" /etc/group;
if [ $? -eq 0 ]; then
   groupdel "$username"
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
### Remove php5 packages if installed
############

echo -e "\nChecking for previously installed php5 packages."
# Get list of installed packages
php5packages="$(dpkg --get-selections | awk '{ print $1 }' | grep 'php5')"
if [[ -z "$php5packages" ]] ; then
  echo -e "\nNo php5 packages found."
else
  echo -e "\nFound php5 packages installed.  It is recomended to uninstall all php before"
  echo -e "proceeding as BrewPi requires php7 and will install it during the install"
  read -p "process.  Would you like to clean this up before proceeding?  [Y/n]: " yn  < /dev/tty
  case $yn in
    [Nn]* )
      echo -e "\nUnable to proceed with php5 installed, exiting.";
      exit 1;;
    * )
      php_packages="$(dpkg --get-selections | awk '{ print $1 }' | grep 'php')"
      # Loop through the php5 packages that we've found
      for pkg in ${php_packages,,}; do
        echo -e "\nRemoving '$pkg'.\n"
        sudo apt remove --purge $pkg -y
      done
	  echo -e "\nCleanup of the php environment complete."
      ;;
  esac
fi

############
### Remove nginx packages if installed
############

echo -e "\nChecking for previously installed nginx packages."
# Get list of installed packages
nginxPackage="$(dpkg --get-selections | awk '{ print $1 }' | grep 'nginx')"
if [[ -z "$nginxPackage" ]] ; then
  echo -e "\nNo nginx packages found."
else
  echo -e "\nFound nginx packages installed.  It is recomended to uninstall nginx before"
  echo -e "proceeding as BrewPi requires apache2 and they will conflict with each other."
  read -p "Would you like to clean this up before proceeding?  [Y/n]: " yn  < /dev/tty
  case $yn in
    [Nn]* )
      echo -e "\nUnable to proceed with nginx installed, exiting.";
      exit 1;;
    * )
      # Loop through the php5 packages that we've found
      for pkg in ${NGINXPACKAGES,,}; do
        echo -e "\nRemoving '$pkg'.\n"
        sudo apt remove --purge $pkg -y
      done
	  echo -e "\nCleanup of the nginx environment complete."
      ;;
  esac
fi

############
### Cleanup local packages
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
### Remove device rules
###########

rules="/etc/udev/rules.d/99-arduino.rules"
if [ -f "$rules" ]; then
  echo -e "\nRemoving udev rules."
  rm "$rules"
  udevadm control --reload-rules
  udevadm trigger
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
