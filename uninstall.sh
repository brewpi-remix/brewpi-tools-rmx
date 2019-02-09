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

# Packages to be uninstalled via apt
APTPACKAGES="git-core pastebinit build-essential git arduino-core libapache2-mod-php apache2 python-configobj python-dev python-pip php-xml php-mbstring php-cgi php-cli php-common php"
# nginx packages to be uninstalled via apt if present
NGINXPACKAGES="libgd-tools, fcgiwrap, nginx-doc, ssl-cert, fontconfig-config, fonts-dejavu-core, libfontconfig1, libgd3, libjbig0, libnginx-mod-http-auth-pam, libnginx-mod-http-dav-ext, libnginx-mod-http-echo, libnginx-mod-http-geoip, libnginx-mod-http-image-filter, libnginx-mod-http-subs-filter, libnginx-mod-http-upstream-fair, libnginx-mod-http-xslt-filter, libnginx-mod-mail, libnginx-mod-stream, libtiff5, libwebp6, libxpm4, libxslt1.1, nginx, nginx-common, nginx-full"
# Packages to be uninstalled via pip
PIPPACKAGES="pyserial psutil simplejson gitpython configobj"

############
### Check privilges and permissions
############

func_getroot() {
  ### Check if we have root privs to run
  if [[ $EUID -ne 0 ]]; then
     echo -e "This script must be run as root: sudo ./$THISSCRIPT" 1>&2
     exit 1
  fi
}

############
### Cleanup cron
############

func_cron() {
  # Clear out the old brewpi cron if it exists
  if [ -f /etc/cron.d/brewpi ]; then
    echo -e "\nResetting cron." > /dev/tty
    rm -f /etc/cron.d/brewpi
    /etc/init.d/cron restart
  fi
}

############
### Cleanup syslogd
############

func_syslogd() {
  ddir="/etc/systemd/system"
  targets="$(grep -rl "# Created for BrewPi version" $ddir)"

  for target in $targets
  do
    filename="$(basename $target)"
    name="$(basename -s ".service" $target)"
    echo -e "\nRemoving $name daemon:" > /dev/tty
    echo -e "Stopping $name daemon." > /dev/tty
    eval "systemctl stop $name"
    echo -e "Disabling $name daemon." > /dev/tty
    eval "systemctl disable $name"
    echo -e "Removing leftover files." > /dev/tty
    rm "/etc/systemd/system/$filename" 2> /dev/null
    rm "/etc/systemd/system/multi-user.target.wants/$filename" 2> /dev/null
    echo -e "Reloading systemd configuration." > /dev/tty
    systemctl daemon-reload
    echo -e "Resetting any failed systemd daemons." > /dev/tty
    systemctl reset-failed
  done
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
      echo -e "\nAttempting graceful shutdown of process $pid." > /dev/tty
      kill -15 "$pid"
      sleep 2
      if ps -p $pid > /dev/null 2>&1; then
        echo -e "\nTrying a little harder to terminate process $pid." > /dev/tty
        kill -2 "$pid"
        sleep 2
        if ps -p $pid > /dev/null 2>&1; then
          echo -e "\nBeing more forceful with process $pid." > /dev/tty
          kill -1 "$pid"
          sleep 2
          while ps -p $pid > /dev/null 2>&1;
          do
            echo -e "\nBeing really insistent about killing process $pid now." > /dev/tty
            echo -e "(I'm going to keep doing this till the process(es) are gone.)" > /dev/tty
            kill -9 "$pid"
            sleep 2
          done
        fi
      fi
    fi
  done
}

############
### Remove all BrewPi Packages
############

func_delrepo() {
  # Wipe out tools
  if [ -d "/home/$SUDO_USER/brewpi-tools-rmx" ]; then
    echo -e "\nClearing /home/$SUDO_USER/brewpi-tools-rmx." > /dev/tty
    rm -fr "/home/$SUDO_USER/brewpi-tools-rmx"
  fi
  # Wipe out legacy tools
  if [ -d "/home/$SUDO_USER/brewpi-tools" ]; then
    echo -e "\nClearing /home/$SUDO_USER/brewpi-tools." > /dev/tty
    rm -fr "/home/$SUDO_USER/brewpi-tools"
  fi
  # Wipe out BrewPi scripts
  if [ -d /home/brewpi ]; then
    echo -e "\nClearing /home/brewpi." > /dev/tty
    rm -fr /home/brewpi
  fi
  # Wipe out www if it exists and is not empty
  if [ -d /var/www/html ]; then
    if [ ! -z "$(ls -A /var/www/html)" ]; then
      echo -e "\nClearing /var/www/html." > /dev/tty
      rm -fr /var/www/html
        # Re-create html durectory
      mkdir /var/www/html
      chown www-data:www-data /var/www/html
    fi
  fi
}

############
### Remove brewpi user/group
############

func_cleanusers() {
  username="$SUDO_USER"
  if getent group brewpi | grep &>/dev/null "\b${username}\b"; then
    echo > /dev/tty
    deluser $SUDO_USER brewpi
  fi
  if getent group www-data | grep &>/dev/null "\b${username}\b"; then
    echo > /dev/tty
    deluser $SUDO_USER www-data
  fi
  username="www-data"
  if getent group brewpi | grep &>/dev/null "\b${username}\b"; then
    echo > /dev/tty
    deluser www-data brewpi
  fi
  username="brewpi"
  if getent group www-data | grep &>/dev/null "\b${username}\b"; then
    echo > /dev/tty
    deluser brewpi www-data
  fi
  if id "$username" > /dev/null 2>&1; then
    echo -e "\nRemoving user $username." > /dev/tty
    userdel "$username"
  fi
  egrep -i "^$username" /etc/group;
  if [ $? -eq 0 ]; then
     groupdel "$username"
  fi
}

############
### Reset Apache
############

func_resetapache() {
  # Reset Apache config to stock
  if [ -f /etc/apache2/apache2.conf ]; then
    if grep -qF "KeepAliveTimeout 99" /etc/apache2/apache2.conf; then
      echo -e "\nResetting /etc/apache2/apache2.conf." > /dev/tty
      sed -i -e 's/KeepAliveTimeout 99/KeepAliveTimeout 5/g' /etc/apache2/apache2.conf
      /etc/init.d/apache2 restart
    fi
  fi
}

############
### Remove pip packages
############

func_delpip() {
  echo -e "\nChecking for pip packages installed with BrewPi." > /dev/tty
  if pip &>/dev/null; then
    pipInstalled=$(pip list --format=legacy)
    if [ $? -eq 0 ]; then
      pipInstalled=$(echo "$pipInstalled" | awk '{ print $1 }')
      for pkg in ${PIPPACKAGES,,}; do
        if [[ ${pipInstalled,,} == *"$pkg"* ]]; then
          echo -e "\nRemoving '$pkg'.\n" > /dev/tty
          pip uninstall $pkg -y
        fi
      done
    fi
  fi
}

############
### Remove apt packages
############

func_delapt() {
  echo -e "\nChecking for apt packages installed with BrewPi." > /dev/tty
  # Get list of installed packages
  packagesInstalled=$(dpkg --get-selections | awk '{ print $1 }')
  # Loop through the required packages and uninstall those in $APTPACKAGES
  for pkg in ${APTPACKAGES,,}; do
    if [[ ${packagesInstalled,,} == *"$pkg"* ]]; then
      echo -e "\nRemoving '$pkg'.\n" > /dev/tty
        apt remove --purge $pkg -y
    fi
  done
}

############
### Remove php5 packages if installed
############

func_delphp5() {
  echo -e "\nChecking for previously installed php5 packages." > /dev/tty
  # Get list of installed packages
  php5packages="$(dpkg --get-selections | awk '{ print $1 }' | grep 'php5')"
  if [[ -z "$php5packages" ]] ; then
    echo -e "\nNo php5 packages found." > /dev/tty
  else
    echo -e "\nFound php5 packages installed.  It is recomended to uninstall all php before" > /dev/tty
    echo -e "proceeding as BrewPi requires php7 and will install it during the install" > /dev/tty
    read -p "process.  Would you like to clean this up before proceeding?  [Y/n]: " yn  < /dev/tty
    case $yn in
      [Nn]* )
        echo -e "\nUnable to proceed with php5 installed, exiting."; > /dev/tty
        exit 1;;
      * )
        php_packages="$(dpkg --get-selections | awk '{ print $1 }' | grep 'php')"
        # Loop through the php5 packages that we've found
        for pkg in ${php_packages,,}; do
          echo -e "\nRemoving '$pkg'.\n" > /dev/tty
          apt remove --purge $pkg -y
        done
          echo -e "\nCleanup of the php environment complete." > /dev/tty
        ;;
    esac
  fi
}

############
### Remove nginx packages if installed
############

func_delnginx() {
  echo -e "\nChecking for previously installed nginx packages." > /dev/tty
  # Get list of installed packages
  nginxPackage="$(dpkg --get-selections | awk '{ print $1 }' | grep 'nginx')"
  if [[ -z "$nginxPackage" ]] ; then
    echo -e "\nNo nginx packages found." > /dev/tty
  else
    echo -e "\nFound nginx packages installed.  It is recomended to uninstall nginx before" > /dev/tty
    echo -e "proceeding as BrewPi requires apache2 and they will conflict with each other." > /dev/tty
    read -p "Would you like to clean this up before proceeding?  [Y/n]: " yn  < /dev/tty
    case $yn in
      [Nn]* )
        echo -e "\nUnable to proceed with nginx installed, exiting."; > /dev/tty
        exit 1;;
      * )
        # Loop through the php5 packages that we've found
        for pkg in ${NGINXPACKAGES,,}; do
          echo -e "\nRemoving '$pkg'.\n" > /dev/tty
          apt remove --purge $pkg -y
        done
          echo -e "\nCleanup of the nginx environment complete." > /dev/tty
        ;;
    esac
  fi
}

############
### Cleanup local packages
############

func_cleanapt() {
  # Cleanup
  echo -e "\nCleaning up local apt packages." > /dev/tty
  apt clean -y
  apt autoclean -y
  apt autoremove --purge -y
}

############
### Change hostname
###########

func_resethost() {
  oldHostName=$(hostname)
  newHostName="raspberrypi"
  if [ "$oldHostName" != "$newHostName" ]; then
    echo -e "\nResetting hostname from $oldhostname back to $newhostname." > /dev/tty
    sed1="sed -i 's/$oldHostName/$newHostName/g' /etc/hosts"
    sed2="sed -i 's/$oldHostName/$newHostName/g' /etc/hostname"
    eval $sed1
    eval $sed2
    hostnamectl set-hostname $newHostName
    /etc/init.d/avahi-daemon restart
    echo -e "\nYour hostname has been changed back to '$newHostName'.\n" > /dev/tty
    echo -e "(If your hostname is part of your prompt, your prompt will" > /dev/tty
    echo -e "not change until you log out and in again.  This will have" > /dev/tty
    echo -e "no effect on anything but the way the prompt looks.)" > /dev/tty
    sleep 3
  fi
}

############
### Remove device rules
###########

func_resetudev() {
  rules="/etc/udev/rules.d/99-arduino.rules"
  if [ -f "$rules" ]; then
    echo -e "\nRemoving udev rules." > /dev/tty
    rm "$rules"
    udevadm control --reload-rules
    udevadm trigger
  fi
}

############
### Reset password
###########

func_resetpwd() {
  if [ getent passwd "pi" > /dev/null 2&>1 ]; then
    echo -e "\nResetting password for 'pi' back to 'raspberry'." > /dev/tty
    echo "pi:raspberry" | chpasswd
  fi
}

############
### Choose uninstall level
###########

func_wipelevel () {
  local level=""
  # Return 2 = least (stop and kill, remove repos, remove users/groups, reset Apache)
  # Return 1 = middle (Additionally reset host name, reset Pi password)
  # Return 0 = harsh (Additionally wipe all apt and pip packages)
  echo -e "\nSelect the level of uninstall you wish to execute.  The least is level [2]" > /dev/tty
  echo -e "which is probably appropriate if you have an issue and are looking to cleanup" > /dev/tty
  echo -e "and reinstall.  Level [1] will reset the hostname and the password for 'pi'" > /dev/tty
  echo -e "back to 'raspberry.'  Level [0] is the most intense, adding the execution of" > /dev/tty
  echo -e "apt and pip package removals.  [0] is likely only appropriate for testers and" > /dev/tty
  echo -e "you should not run it unless you know what you are doing or someone tells you" > /dev/tty
  echo -e "that you need to.\n" > /dev/tty
  echo -e "   [2] - Normal uninstall of BrewPi repositories, services and devices" > /dev/tty
  echo -e "   [1] - Everything in [2] plus reset hostname and pi password" > /dev/tty
  echo -e "   [0] - Everything in [2] and [1] plus wipe pip and apt packages\n" > /dev/tty
  while [ -z "$level" ] || ! [[ "$level" =~ ^[0-9]+$ ]] || ([ "$level" -lt 0 ] || [ "$level" -gt 2 ])
  do
    read -p "Enter level of uninstall to execute 0, 1, or 2.: " level < /dev/tty
  done
  echo "$level"
}

############
### Main
###########

main() {
  func_getroot # Check for root privs
  echo -e "\n***Script BrewPi Uninstaller starting.***" > /dev/tty
  cd ~ # Start from home
  level="$(func_wipelevel)"
  [ "$level" -le 2 ] && func_cron # Clean up crontab
  [ "$level" -le 2 ] && func_syslogd # Cleanup syslogd
  [ "$level" -le 2 ] && func_killproc # Kill all brewpi procs
  [ "$level" -le 2 ] && func_delrepo # Remove all the repos
  [ "$level" -le 2 ] && func_cleanusers # Clean up users and groups
  [ "$level" -le 2 ] && func_resetapache # Reset Apache config to stock
  [ "$level" -le 0 ] && func_delpip # Remove pip packages
  [ "$level" -le 0 ] && func_delapt # Remove apt dependencies
  [ "$level" -le 2 ] && func_delphp5 # Remove php5 packages
  [ "$level" -le 2 ] && func_delnginx # Remove nginx
  [ "$level" -le 2 ] && func_cleanapt # Clean up apt packages locally
  [ "$level" -le 1 ] && func_resethost # Reset hostname
  [ "$level" -le 2 ] && func_resetudev # Remove udev rules
  [ "$level" -le 1 ] && func_resetpwd # Reset pi password
  echo -e "\n***Script BrewPi Uninstaller complete.***" > /dev/tty
}

############
### Start the script
############

sleep 2
main # Moved to functions to prevent broken execution with wget

############
### Work Complete
###########

exit 0
