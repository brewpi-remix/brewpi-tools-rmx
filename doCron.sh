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
  defaultScriptPath="$(echo $_shadow | cut -d':' -f6)"
else
  echo "Unable to retrieve brewpi's home directory. Manual install"
  echo "may be necessary."
  exit 1
fi

############
### Start the script
############

echo -e "\n***Script $THISSCRIPT starting.***\n"

echo -e "Updating cron for the brewpi user.\n"

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
### doCronEntry:  Prompts to create or update crontab entry.  Two arguments:
############

function doCronEntry {
  # Prompts to create or update crontab entry.  Two arguments:
  #   $1 = Entry name (i.e. brewpi or wifi)
  #   $2 = Cron tab entry
  entry=$1
  newEntry=$2
  echo -e "Checking entry for $entry."
  # find old entry for this name
  oldEntry=$(grep -A1 "entry:$entry" "$cronfile" | tail -n 1)
  # check whether it is up to date
  if [ "$oldEntry" != "$newEntry" ]; then
    # if not up to date, prompt to replace
    echo -e "\nYour current cron entry:"
    if [ -z "$oldEntry" ]; then
      echo "None."
    else
      echo "$oldEntry"
    fi
    echo -e "\nLatest version of this cron entry:"
    echo -e "$newEntry"
    echo -e "\nYour current cron entry differs from the latest version, would you like me"
    read -p "to update it? [Y/n]: " yn </dev/tty
    if [ -z "$yn" ]; then
      yn="y" # no entry/enter = yes
    fi
    case "$yn" in
      y | Y | yes | YES| Yes )
        line=$(grep -n "entry:$entry" /etc/cron.d/brewpi | cut -d: -f 1)
        if [ -z "$line" ]; then
          echo -e "\nAdding new cron entry to file.\n"
          # entry did not exist, add at end of file
          echo "# entry:$entry" | tee -a "$cronfile" > /dev/null
          echo "$newEntry" | tee -a "$cronfile" > /dev/null
        else
          echo -e "\nReplacing cron entry on line $line with newest version."
          # get line number to replace
          cp "$cronfile" /tmp/brewpi.cron
          # write head of old cron file until replaced line
          head -"$line" /tmp/brewpi.cron | tee "$cronfile" > /dev/null
          # write replacement
          echo "$newEntry" | tee -a "$cronfile" > /dev/null
          # write remainder of old file
          tail -n +$((line+2)) /tmp/brewpi.cron | tee -a "$cronfile" > /dev/null
        fi
        ;;
      * )
        echo -e "\nSkipping entry for $entry.\n"
        ;;
    esac
  fi
  echo -e "Done checking entry $entry."
}

############
# Update /etc/cron.d/brewpi
# Settings are stored in the cron file itself:
#   active entries
#   scriptpath
#   stdout/stderr redirect paths
#
# Entries is a list of entries that should be active.
#   entries="brewpi wifi"
# If an entry is disabled, it is prepended with ~
#   entries="brewpi ~wifi"
#
# Each entry is two lines, one comment with the entry name, one for the actual entry:
#   entry:wifi
#   */10 * * * * root sudo -u brewpi touch $stdoutpath $stderrpath; $scriptpath/utils/wifiChecker.sh 1>>$stdoutpath 2>>$stderrpath &
#
# This script checks whether the available entries are up-to-date.  If not,
# it can replace the entry with a new version.  If the entry is not in
# entries (enabled or disabled), it needs to be disabled or added.
# Known entries:
#   brewpi
#   wifi
#
# Full Example:
#   stderrpath="/home/brewpi/logs/stderr.txt"
#   stdoutpath="/home/brewpi/logs/stdout.txt"
#   scriptpath="/home/brewpi"
#   entries="brewpi wifi"
#   # entry:brewpi
#   * * * * * brewpi python $scriptpath/brewpi.py --checkstartuponly --dontrunfile $scriptpath/brewpi.py 1>/dev/null 2>>$stderrpath; [ $? != 0 ] && python -u $scriptpath/brewpi.py 1>$stdoutpath 2>>$stderrpath &
#   # entry:wifi
#   */10 * * * * root sudo -u brewpi touch $stdoutpath $stderrpath; $scriptpath/utils/wifiChecker.sh 1>>$stdoutpath 2>>$stderrpath &
#
############

############
### Check for old crontab entry
############

crontab -u brewpi -l > /tmp/oldcron 2> /dev/null
if [ -s /tmp/oldcron ]; then
  if grep -q "brewpi.py" /tmp/oldcron; then
    > /tmp/newcron||die
    firstLine=true
    while read line
    do
      if [[ "$line" == *brewpi.py* ]]; then
        case "$line" in
          \#*) # Copy commented lines
            echo "$line" >> /tmp/newcron;
            continue ;;
          *)   # Process anything else
            echo -e "It looks like you have an old brewpi entry in your crontab."
            echo -e "The cron job to start/restart brewpi has been moved to cron.d."
            echo -e "This means the lines for brewpi in your crontab are not needed"
            echo -e "anymore.  Nearly all users will want to comment out this line.\n"
            firstLine=false
            echo "crontab line: $line"
            read -p "Do you want to comment out this line? [Y/n]: " yn </dev/tty
            case "$yn" in
              ^[Yy]$ ) echo "Commenting line:\n";
                            echo "# $line" >> /tmp/newcron;;
              ^[Nn]$ ) echo -e "Keeping original line:\n";
                            echo "$line" >> /tmp/newcron;;
              * ) echo "Not a valid choice, commenting out old line.";
                              echo "Commenting line:\n";
                                  echo "# $line" >> /tmp/newcron;;
            esac
        esac
      fi
    done < /tmp/oldcron
        # Install the updated old cron file to the new location
    crontab -u brewpi /tmp/newcron||die 2> /dev/null
    rm /tmp/newcron||warn
    if ! ${firstLine}; then
      echo -e "Updated crontab to read:\n"
      crontab -u brewpi -l||die 2> file
      echo -e "Finished updating crontab."
    fi
  fi
fi
rm /tmp/oldcron||warn

# default cron lines for brewpi
cronfile="/etc/cron.d/brewpi"
# make sure it exists
touch "$cronfile"

# get variables from old cron job. First grep gets the line, second one the
# string; tr removes the quotes. In cron file: entries="brewpi wifi"
entries=$(grep -m1 'entries=".*"' /etc/cron.d/brewpi | grep -oE '".*"' | tr -d \")
scriptpath=$(grep -m1 'scriptpath=".*"' /etc/cron.d/brewpi | grep -oE '".*"' | tr -d \")
stdoutpath=$(grep -m1 'stdoutpath=".*"' /etc/cron.d/brewpi | grep -oE '".*"' | tr -d \")
stderrpath=$(grep -m1 'stderrpath=".*"' /etc/cron.d/brewpi | grep -oE '".*"' | tr -d \")

# if the variables did not exist, add the defaults
if [ -z "$entries" ]; then
  entries="brewpi"
  echo -e "No cron file present, or it is an old version, starting fresh.\n"
  rm -f "$cronfile"
  echo "entries=\"brewpi\"" | tee "$cronfile" > /dev/null
fi

if [ -z "$scriptpath" ]; then
  scriptpath="$defaultScriptPath"
  echo -e "No previous setting for scriptpath found, using default:\n$scriptpath.\n"
  entry="1iscriptpath=$scriptpath"
  sed -i "$entry" "$cronfile"
fi

if [ -z "$stdoutpath" ]; then
  stdoutpath="/home/brewpi/logs/stdout.txt"
  echo -e "No previous setting for stdoutpath found, using default:\n$stdoutpath.\n"
  entry="1istdoutpath=$scriptpath/logs/stdout.txt"
  sed -i "$entry" "$cronfile"
fi

if [ -z "$stderrpath" ]; then
  stderrpath="/home/brewpi/logs/stdout.txt"
  echo -e "No previous setting for stderrpath found, using default:\n$stderrpath.\n"
  entry="1istderrpath=$scriptpath/logs/stderr.txt"
  sed -i "$entry" "$cronfile"
fi

# crontab entries
brewpicron='* * * * * brewpi python $scriptpath/brewpi.py --checkstartuponly --dontrunfile $scriptpath/brewpi.py 1>/dev/null 2>>$stderrpath; [ $? != 0 ] && python -u $scriptpath/brewpi.py 1>$stdoutpath 2>>$stderrpath &'
wificheckcron='*/10 * * * * root sudo -u brewpi touch $stdoutpath $stderrpath; $scriptpath/utils/wifiChecker.sh 1>>$stdoutpath 2>>$stderrpath &'

# Entry for brewpi.py
found=false
for entry in $entries; do
  # entry for brewpi.py
  if [ "$entry" == "brewpi" ] ; then
    found=true
    doCronEntry brewpi "$brewpicron"
    break
  fi
done

# Entry for WiFi check script
found=false
for entry in $entries; do
  if [ "$entry" == "wifi" ] ; then
    # check whether cron entry is up to date
    found=true
    doCronEntry wifi "$wificheckcron"
    break
  elif [ "$entry" == "~wifi" ] ; then
    echo "WiFi checker is disabled."
    found=true
    break
  fi
done

# If there was no entry for wifi, ask to add it or disable it
wlan=$(cat /proc/net/wireless | perl -ne '/(\w+):/ && print $1')
if [ "$found" == false ]; then
  echo -e "\nNo setting found for wifi check script."
  if [[ ! -z "$wlan" ]]; then
    echo -e "\nIt looks like you're running a WiFi adapter on your Pi.  Some users"
    echo -e "have experienced issues with the adapter losing network connectivity."
    echo -e "This script can create a scheduled job to help reconnect the Pi"
    echo -e "to your network.\n"
      read -p "Would you like to create this job? [Y/n]: " yn </dev/tty
    if [ -z "$yn" ]; then
      yn="y"
    fi
    case "$yn" in
      y | Y | yes | YES| Yes )
        # update entries="..." to entries="... wifi" (enables check)
        sed -i '/entries=.*/ s/"$/ wifi"/' "$cronfile"
        doCronEntry wifi "$wificheckcron"
        ;;
      * )
       # update entries="..." to entries="... ~wifi" (disables check)
       sed -i '/entries=.*/ s/"$/ ~wifi"/' "$cronfile"
       echo -e "\nSetting wifiChecker to disabled."
       ;;
    esac
  else
    echo -e "\nIt looks like you're not running a WiFi adapter on your Pi.\n"
  fi
fi

echo -e "\nRestarting cron:"
/etc/init.d/cron restart||die

