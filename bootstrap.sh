#!/bin/bash

# Copyright (C) 2018,2019  Lee C. Bussy (@LBussy)

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
### Handle logging
############

timestamp() {
  # Add date in '2019-02-26 08:19:22' format to log
  while read -r; do
    if [ -n "$REPLY" ]; then # Skip blank lines
      printf '%(%Y-%m-%d %H:%M:%S)T %s\n' -1 "$REPLY"
    fi
  done
}

doLog() {
  [[ "$@" == *"-nolog"* ]] && return # Turn off logging
  # Set up our local variables
  declare local thisscript scriptname realuser homepath shadow
  # Explicit scriptname (creates log name) since we start
  # before the main script
  thisscript="bootstrap.sh"
  scriptname="${thisscript%%.*}"
  # Get home directory for logging
  if [ "$SUDO_USER" ]; then realuser="$SUDO_USER"; else realuser=$(whoami); fi
  shadow="$( (getent passwd "$realuser") 2>&1)"
  if [ -n "$shadow" ]; then
    homepath=$(echo "$shadow" | cut -d':' -f6)
  else
    echo -e "\nERROR: Unable to retrieve $realuser's home directory. Manual install"
    echo -e "may be necessary."
    exit 1
  fi
  # Tee all output to log file in home directory
  exec > >(tee >(timestamp >>"$homepath/$scriptname.log")) 2>&1
}

############
### Init
############

init() {
  # Set up some project variables we won't have running as a bootstrap
  PACKAGE="BrewPi-Tools-RMX"
  GITBRNCH="devel" # TODO:  Get this from URL
  THISSCRIPT="bootstrap.sh"
  VERSION="0.5.1.3"
  CMDLINE="curl -L devinstall.brewpiremix.com | sudo bash"
  # These should stay the same
  GITRAW="https://raw.githubusercontent.com/lbussy"
  GITHUB="https://github.com/lbussy"
  # Cobble together some strings
  SCRIPTNAME="${THISSCRIPT%%.*}"
  GITPROJ="${PACKAGE,,}"
  GITHUB="$GITHUB/$GITPROJ.git"
  GITRAW="$GITRAW/$GITPROJ/$GITBRNCH/$THISSCRIPT"
  GITCMD="-b $GITBRNCH --single-branch $GITHUB"
  # Website for network test
  GITTEST="$GITHUB"
  # Packages to be installed/checked via apt
  APTPACKAGES="git"
}

############
### Command line arguments
############

# usage outputs to stdout the --help usage message.
usage() {
cat << EOF

$PACKAGE $THISSCRIPT version $VERSION

Usage: sudo ./$THISSCRIPT"
EOF
}

# version outputs to stdout the --version message.
version() {
cat << EOF

$THISSCRIPT ($PACKAGE) $VERSION

Copyright (C) 2018,2019 Lee C. Bussy (@LBussy)

This is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published
by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.
<https://www.gnu.org/licenses/>

There is NO WARRANTY, to the extent permitted by law.
EOF
}

# Parse arguments and call usage or version
arguments() {
  while [[ "$#" -gt 0 ]]; do
  arg="$1"
    case "$arg" in
      --h* )
        usage; exit 0 ;;
      --v* )
        version; exit 0 ;;
    esac
  done
}

############
### Make sure command is running with sudo
############

checkroot() {
  if [ "$SUDO_USER" ]; then REALUSER="SUDO_USER"; else REALUSER=$(whoami); fi
  if [[ "$EUID" -ne 0 ]]; then
    sudo -n true 2> /dev/null
    local retval="$?"
    if [ "$retval" -eq 0 ]; then
      echo -e "\nNot runing as root, relaunching correctly.\n"
      sleep 2
      eval "$CMDLINE"
      exit "$?"
    else
      # sudo not available, give instructions
      echo -e "\nThis script must be run with root priviledges."
      echo -e "Enter the following command as one line:"
      echo -e "$CMDLINE" 1>&2
      exit 1
    fi
  fi
  # And get the user home directory
  shadow="$( (getent passwd "$REALUSER") 2>&1)"
  retval="$?"
  if [ "$retval" -eq 0 ]; then
    HOMEPATH=$(echo "$shadow" | cut -d':' -f6)
  else
    echo -e "\nUnable to retrieve $REALUSER's home directory. Manual install"
    echo -e "may be necessary."
    exit 1
  fi
}

############
### Provide terminal escape codes
############

term() {
  tput colors > /dev/null 2>&1
  local retval="$?"
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
### Functions to catch/display errors during setup
############

warn() {
  local fmt="$1"
  command shift 2>/dev/null
  echo -e "\n$fmt"
  echo -e "${@}"
  echo -e "\n*** ERROR ERROR ERROR ERROR ERROR ***"
  echo -e "-------------------------------------"
  echo -e "See above lines for error message."
  echo -e "Setup NOT completed.\n"
}

die() {
  local st="$?"
  warn "$@"
  exit "$st"
}

############
### Instructions
############

instructions() {
  echo -e "         ___                ___ _   ___           _     "
  echo -e "        | _ )_ _ _____ __ _| _ (_) | _ \___ _ __ (_)_ __"
  echo -e "        | _ \ '_/ -_) V  V /  _/ | |   / -_) '  \| \ \ /"
  echo -e "        |___/_| \___|\_/\_/|_| |_| |_|_\___|_|_|_|_/_\_\ "

  echo -e "\nYou will be presented with some choices during the install. Most frequently"
  echo -e "you will see a 'yes or no' choice, with the default choice capitalized like"
  echo -e "so: [y/N]. Default means if you hit <enter> without typing anything, you will"
  echo -e "make the capitalized choice, i.e. hitting <enter> when you see [Y/n] will"
  echo -e "default to 'yes.'"

  echo -e "\nYes/no choices are not case sensitive. However; passwords, system names and"
  echo -e "install paths are. Be aware of this. There is generally no difference between"
  echo -e "'y', 'yes', 'YES', 'Yes'; you get the idea. In some areas you are asked for a"
  echo -e "path; the default/recommended choice is in braces like: [/home/brewpi]."
  echo -e "Pressing <enter> without typing anything will take the default/recommended"
  echo -e "choice. In general, unless you know what you are doing, going with a non-"
  echo -e "default path is not recommended as not all possibilities can be reasonably"
  echo -e "tested."

  echo -e "\nPress <enter> when you are ready to proceed."
  read < /dev/tty
}

############
### Check for default 'pi' password and gently prompt to change it now
############

checkpass() {
  local user_exists=$(id -u 'pi' > /dev/null 2>&1; echo $?)
  if [ "$user_exists" -eq 0 ]; then
    salt=$(getent shadow "pi" | cut -d$ -f3)
    extpass=$(getent shadow "pi" | cut -d: -f2)
    match=$(python -c 'import crypt; print crypt.crypt("'"raspberry"'", "$6$'${salt}'")')
    [ "${match}" == "${extpass}" ] && badpwd=true || badpwd=false
    if [ "$badpwd" = true ]; then
      echo -e "Default password found for the 'pi' account. This should be changed."
      while true; do
          read -p "Do you want to change the password now? [Y/n]: " yn  < /dev/tty
          case "$yn" in
              '' ) setpass=1; break ;;
              [Yy]* ) setpass=1; break ;;
              [Nn]* ) break ;;
              * ) echo "Enter [y]es or [n]o." ;;
          esac
      done
    fi
    if [ ! -z "$setpass" ]; then
      echo
      until passwd pi < /dev/tty; do sleep 2; echo; done
      echo -e "\nYour password has been changed, remember it or write it down now."
      sleep 5
    fi
  fi
}

############
### Set timezone
###########

settime() {
  date=$(date)
  while true; do
    echo -e "The time is currently set to $date."
    if [ "$(date | cut -d ' ' -f 5)" == "GMT" ]; then
      # Probably never been set
      read -p "Is this correct? [y/N]: " yn  < /dev/tty
      case "$yn" in
        '' ) dpkg-reconfigure tzdata; break ;;
        [Nn]* ) dpkg-reconfigure tzdata; break ;;
        [Yy]* ) echo ; break ;;
        * ) echo "Enter [y]es or [n]o." ;;
      esac
    else
      # Probably been set
      read -p "Is this correct? [Y/n]: " yn  < /dev/tty
      case "$yn" in
        [Nn]* ) dpkg-reconfigure tzdata; break ;;
        [Yy]* ) break ;;
        * ) break ;;
      esac
    fi
  done
}

############
### Change hostname
###########

hostname() {
  oldHostName=$(hostname)
  if [ "$oldHostName" = "raspberrypi" ]; then
    while true; do
      echo -e "Your hostname is set to '$oldHostName'. Do you"
      read -p "want to change it now, maybe to 'brewpi'? [Y/n]: " yn < /dev/tty
      case "$yn" in
          '' ) sethost=1; break ;;
          [Yy]* ) sethost=1; break ;;
          [Nn]* ) break ;;
          * ) echo "Enter [y]es or [n]o." ; sleep 1 ; echo ;;
      esac
    done
    echo
    if [ "$sethost" -eq 1 ]; then
      echo -e "You will now be asked to enter a new hostname."
      while
        read -p "Enter new hostname: " host1  < /dev/tty
        read -p "Enter new hostname again: " host2 < /dev/tty
        [[ -z "$host1" || "$host1" != "$host2" ]]
      do
        echo -e "\nHost names blank or do not match.\n";
        sleep 1
      done
      echo
      newHostName=$(echo "$host1" | awk '{print tolower($0)}')
      eval "sed -i 's/$oldHostName/$newHostName/g' /etc/hosts"||die
      eval "sed -i 's/$oldHostName/$newHostName/g' /etc/hostname"||die
      hostnamectl set-hostname "$newHostName"
      /etc/init.d/avahi-daemon restart
      echo -e "\nYour hostname has been changed to '$newHostName'.\n"
      echo -e "(If your hostname is part of your prompt, your prompt will"
      echo -e "not change until you log out and in again.  This will have"
      echo -e "no effect on anything but the way the prompt looks.)"
      sleep 5
    fi
  fi
}

############
### Check for network connection
###########

checknet() {
  echo -e "\nChecking for connection to GitHub."
  wget -q --spider "$GITTEST"
  local retval="$?"
  if [ "$retval" -ne 0 ]; then
    echo -e "\n-------------------------------------------------------------\n"
    echo -e "Could not connect to GitHub.  Please check your network and "
    echo -e "try again. A connection to GitHub is required to download the"
    echo -s "$PACKAGE package."
    exit 1
  else
    echo -e "\nConnection to GitHub ok."
  fi
}

############
### Install or update required packages
############

packages() {
  # Run 'apt update' if last run was > 1 week ago
  lastUpdate=$(stat -c %Y /var/lib/apt/lists)
  nowTime=$(date +%s)
  if [ $(("$nowTime" - "$lastUpdate")) -gt 604800 ] ; then
    echo -e "\nLast apt update was over a week ago. Running apt update before updating"
    echo -e "dependencies."
    apt update||die
  fi

  # Now install any necessary packages if they are not installed
  echo -e "\nChecking and installing required dependencies via apt."
  for pkg in $APTPACKAGES; do
    pkgOk=$(dpkg-query -W --showformat='${Status}\n' $pkg | \
      grep "install ok installed")
    if [ -z "$pkgOk" ]; then
      echo -e "\nInstalling '$pkg'."
      apt install "$pkg" -y||die
    fi
  done

  # Get list of installed packages with updates available
  upgradesAvail=$(dpkg --get-selections | xargs apt-cache policy {} | \
    grep -1 Installed | sed -r 's/(:|Installed: |Candidate: )//' | \
    uniq -u | tac | sed '/--/I,+1 d' | tac | sed '$d' | sed -n 1~2p)
  # Loop through the required packages and see if they need an upgrade
  for pkg in $APTPACKAGES; do
    if [[ "$upgradesAvail" == *"$pkg"* ]]; then
      echo -e "\nUpgrading '$pkg'."
      apt install "$pkg"||die
    fi
  done
}

############
### Clone BrewPi-Tools-RMX repo
############

clonetools() {
  echo -e "\nCloning $GITPROJ repo."
  if [ -d "$HOMEPATH/$GITPROJ" ]; then
    if [ "$(ls -A $HOMEPATH/$GITPROJ)" ]; then
      echo -e "\nWarning: $HOMEPATH/$GITPROJ exists and is not empty."
    else
      echo -e "\nWarning: $HOMEPATH/$GITPROJ exists."
    fi
    echo -e "\nIf you are sure you do not need it or you are starting over completely, we can"
    echo =e "delete the old repo by accepting the below prompt."
    echo -e "\nIf you are running multi-chamber and are trying to add a new chamber, select"
    echo -e "'N' below, and add a new chamber by executing:"
    echo -e "'sudo $HOMEPATH/$GITPROJ/install.sh'\n"
    read -p "Remove $HOMEPATH/$GITPROJ? [y/N] " < /dev/tty
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      rm -fr "$HOMEPATH/$GITPROJ"
      echo
    else
      echo -e "\nLeaving $HOMEPATH/$GITPROJ in place and exiting."
      exit 1
    fi
  fi

  gitClone=
  eval "sudo -u $REALUSER git clone $GITCMD $HOMEPATH/$GITPROJ"||die
}

############
### Main function
############

main() {
  log # Start logging
  init # Get constants
  arguments # Check command line arguments
  echo -e "\n***Script $THISSCRIPT starting.***\n"
  checkroot # Make sure we are su into root
  term # Add term command constants
  instructions # Show instructions
  checkpass # Check for default password
  settime # Set timesone
  hostname # Change hostname
  checknet # Check internet connection
  packages # Install and update required packages
  clonetools # Clone tools repo
  eval "$HOMEPATH/$GITPROJ/install.sh -nolog" || die # Start installer
}

############
### Start the script
############

main

############
### Work complete
############

exit 0
