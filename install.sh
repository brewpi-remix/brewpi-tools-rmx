#!/bin/bash

# Copyright (C) 2018, 2019 Lee C. Bussy (@LBussy)
#
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
### Global Declarations
############

# General constants
declare THISSCRIPT TOOLPATH VERSION GITBRNCH GITURL GITPROJ PACKAGE GITPROJWWW
declare GITPROJSCRIPT GITURLWWW GITURLSCRIPT INSTANCES WEBPATH CHAMBER VERBOSE
declare REPLY SOURCE SCRIPTSOURCE SCRIPTPATH CHAMBERNAME WEBSOURCE GRAVITY
declare TILTCOLOR
# Color/character codes
declare BOLD SMSO RMSO FGBLK FGRED FGGRN FGYLW FGBLU FGMAG FGCYN FGWHT FGRST
declare BGBLK BGRED BGGRN BGYLW BGBLU BGMAG BGCYN BGWHT BGRST DOT HHR LHR RESET

############
### Handle logging
############

timestamp() {
    # Add date in '2019-02-26 08:19:22' format to log
    [[ "$VERBOSE" == "true" ]] && length=999 || length=60 # Allow full logging
    while read -r; do
        # Clean and trim line to 60 characters to allow for timestamp on one line
        REPLY="$(clean "$REPLY" 60)"
        # Strip blank lines
        if [ -n "$REPLY" ]; then
            # Add date in '2019-02-26 08:19:22' format to log
            printf '%(%Y-%m-%d %H:%M:%S)T %s\n' -1 "$REPLY"
        fi
    done
}

clean() {
    # Cleanup log line
    local input length dot
    input="$1"
    length="$2"
    # Even though this is defined in term() we need it earlier
    dot="$(tput sc)$(tput setaf 0)$(tput setab 0).$(tput sgr 0)$(tput rc)"
    # If we lead the line with our semaphore, return a blank line
    if [[ "$input" == "$dot"* ]]; then echo ""; return; fi
    # Strip color codes
    input="$(echo "$input" | sed 's,\x1B[[(][0-9;]*[a-zA-Z],,g')"
    # Strip beginning spaces
    input="$(printf "%s" "${input#"${input%%[![:space:]]*}"}")"
    # Strip ending spaces
    input="$(printf "%s" "${input%"${input##*[![:space:]]}"}")"
    # Squash any repeated whitespace within string
    input="$(echo "$input" | awk '{$1=$1};1')"
    # Log only first $length chars to allow for date/time stamp
    input="$(echo "$input" | cut -c-"$length")"
    echo "$input"
}

log() {
    local thisscript scriptname shadow homepath
    [[ "$*" == *"-nolog"* ]] && return # Turn off logging
    # Set up our local variables
    local thisscript scriptname realuser homepath shadow
    # Get scriptname (creates log name) since we start before the main script
    thisscript="$(basename "$(realpath "$0")")"
    scriptname="${thisscript%%.*}"
    # Get home directory for logging
    if [ -n "$SUDO_USER" ]; then realuser="$SUDO_USER"; else realuser=$(whoami); fi
    shadow="$( (getent passwd "$realuser") 2>&1)"
    if [ -n "$shadow" ]; then
        homepath=$(echo "$shadow" | cut -d':' -f6)
    else
        echo -e "\nERROR: Unable to retrieve $realuser's home directory. Manual install"
        echo -e "may be necessary."
        exit 1
    fi
    # Tee all output to log file in home directory
    sudo -u "$realuser" touch "$homepath/$scriptname.log"
    exec > >(tee >(timestamp >> "$homepath/$scriptname.log")) 2>&1
}

############
### Init
############

init() {
    # Set up some project constants
    THISSCRIPT="$(basename "$(realpath "$0")")"
    TOOLPATH="$(cd "$(dirname "$0")" || die ; pwd -P )"
    cd "$TOOLPATH" || die
    if [ -x "$(command -v git)" ] && [ -d .git ]; then
        VERSION="$(git describe --tags "$(git rev-list --tags --max-count=1)")"
        COMMIT="$(git -C "$TOOLPATH" log --oneline -n1)"
        GITBRNCH="$(git branch | grep \* | cut -d ' ' -f2)"
        GITURL="$(git config --get remote.origin.url)"
        GITPROJ="$(basename "$GITURL")"
        GITPROJ="${GITPROJ%.*}"
        PACKAGE="${GITPROJ^^}"
        GITBRNCH="$(git rev-parse --abbrev-ref HEAD)"
        GITPROJWWW="brewpi-www-rmx"
        GITPROJSCRIPT="brewpi-script-rmx"
        # Concatenate URLs
        GITURLWWW="${GITURL/$GITPROJ/$GITPROJWWW}"
        GITURLSCRIPT="${GITURL/$GITPROJ/$GITPROJSCRIPT}"
    else
        echo -e "\nNot a valid git repository. Did you copy this file here?"
        exit 1
    fi
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

Copyright (C) 2018, 2019 Lee C. Bussy (@LBussy)

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
    local arg
    while [[ "$#" -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            --h* )
            usage; exit 0 ;;
            --v* )
            version; exit 0 ;;
            * )
            break;;
        esac
    done
}

############
### Check privileges and permissions
############

checkroot() {
    local retval shadow
    ### Check if we have root privs to run
    if [[ "$EUID" -ne 0 ]]; then
        sudo -n true 2> /dev/null
        retval="$?"
        if [ "$retval" -eq 0 ]; then
            echo -e "\nNot running as root, relaunching correctly."
            sleep 2
            eval "sudo bash $TOOLPATH/$THISSCRIPT $*"
            exit "$?"
        else
            # sudo not available, give instructions
            echo -e "\nThis script must be run as root: sudo $TOOLPATH/$THISSCRIPT $*" 1>&2
            exit 1
        fi
    fi
    # And get the user home directory
    if [ -n "$SUDO_USER" ]; then REALUSER="$SUDO_USER"; else REALUSER=$(whoami); fi
    shadow="$( (getent passwd "$REALUSER") 2>&1)"
    retval="$?"
    if [ "$retval" -eq 0 ]; then
        HOMEPATH="$(echo "$shadow" | cut -d':' -f6)"
    else
        echo -e "\nUnable to retrieve $REALUSER's home directory. Manual install may be necessary."
        exit 1
    fi
}

############
### Provide terminal escape codes
############

term() {
    local retval
    # If we are colors capable, allow them
    tput colors > /dev/null 2>&1
    retval="$?"
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
        # Some constructs
        # "Invisible" period (black FG/BG and a backspace)
        DOT="$(tput sc)$(tput setaf 0)$(tput setab 0).$(tput sgr 0)$(tput rc)"
        HHR="$(eval printf %.0s═ '{1..'"${COLUMNS:-$(tput cols)}"\}; echo)"
        LHR="$(eval printf %.0s─ '{1..'"${COLUMNS:-$(tput cols)}"\}; echo)"
        RESET=$(tput sgr0)  # FG/BG reset to default color
    fi
}

############
### Functions to catch/display errors during execution
############

warn() {
    local fmt
    fmt="$1"
    command shift 2>/dev/null
    echo -e "$fmt"
    echo -e "${@}"
    echo -e "\n*** ERROR ERROR ERROR ERROR ERROR ***" > /dev/tty
    echo -e "-------------------------------------" > /dev/tty
    echo -e "\nSee above lines for error message." > /dev/tty
    echo -e "Setup NOT completed.\n" > /dev/tty
}

die() {
    local st
    st="$?"
    warn "$@"
    exit "$st"
}

############
### See if BrewPi is already installed
###########

findbrewpi() {
    declare home
    home="/home/brewpi"
    INSTANCES=$(find "$home" -name "brewpi.py" 2> /dev/null)
    IFS=$'\n' INSTANCES=("$(sort <<<"${INSTANCES[*]}")") && unset IFS # Sort list
    if [ ${#INSTANCES} -eq 22 ]; then
        echo -e "\nFound BrewPi installed and configured to run in single instance mode.  To"
        echo -e "change to multi-chamber mode you must uninstall this instance configured as"
        echo -e "single-use and re-run the installer to configure multi-chamber."
        exit 1
    fi
}

############
### Check network connection
###########

checknet() {
    echo -e "\nChecking for connection to GitHub."
    wget -q --spider "$GITURL"
    local retval="$?"
    if [ "$retval" -ne 0 ]; then
        echo -e "\n-----------------------------------------------------------------------------"
        echo -e "\nCould not connect to GitHub.  Please check your network and try again. A"
        echo -e "connection to GitHub is required to download the $PACKAGE packages."
        die
    else
        echo -e "\nConnection to GitHub ok."
    fi
}

############
### Check for free space
############

checkfree() {
    local req freek freem freep
    req=512
    freek=$(df -Pk | grep -m1 '\/$' | awk '{print $4}')
    freem="$((freek / 1024))"
    freep=$(df -Pk | grep -m1 '\/$' | awk '{print $5}')
    
    if [ "$freem" -le "$req" ]; then
        echo -e "\nDisk usage is $freep, free disk space is $freem MB,"
        echo -e "Not enough space to continue setup. Installing $PACKAGE requires"
        echo -e "at least $req MB free space."
        exit 1
    else
        echo -e "\nDisk usage is $freep, free disk space is $freem MB."
    fi
}

############
### Ensure chosen chamber name does not conflict with others
############

checkchamber() {
    local chamber retval
    chamber="$1"
    retval=0
    # Check /dev/$chamber
    if [ -L "/dev/$chamber" ]; then
        echo -e "\nA device with the name of /dev/$chamber already exists." > /dev/tty
        ((retval++))
    fi
    # Check /home/brewpi/$chamber
    if [ -d "/home/brewpi/$chamber" ]; then
        echo -e "\nA chamber with the name of /brewpi/$chamber already exists." > /dev/tty
        ((retval++))
    fi
    # Check /var/www/html/$chamber
    if [ -d "/var/www/html/$chamber" ]; then
        echo -e "\nA website with the name of /var/www/html/$chamber already exists." > /dev/tty
        ((retval++))
    fi
    # Check /etc/systemd/system/$chamber.service
    if [ -f "/etc/systemd/system/$chamber.service" ]; then
        echo -e "\nA daemon with the name of /etc/systemd/system/$chamber.service already exists." > /dev/tty
        ((retval++))
    fi
    # If we found a daemon, device, web or directory by that name, return false
    [ "$retval" -gt 0 ] && echo false || echo true
}

############
### Choose a name for the chamber & device, set script path
############

getscriptpath() {
    local chamber chamberName
    # See if we already have chambers installed
    if [ -n "${INSTANCES[*]}" ]; then
        # We've already got BrewPi installed in multi-chamber
        echo -e "\nThe following chambers are already configured on this Pi:\n"
        for instance in $INSTANCES
        do
            echo -e "\t$(dirname "${instance}")"
        done
        # Get $SOURCE, $SCRIPTSOURCE and $WEBSOURCE for git clone
        set -- $INSTANCES
        SCRIPTSOURCE=$(dirname "${1}")
        SOURCE=$(basename "$SCRIPTSOURCE")
        WEBPATH="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* | xargs | cut -d " " -f2)"
        if [ -z "$WEBPATH" ]; then
            echo "Something went wrong searching for /etc/apache2/sites-enabled/000-default*."
            echo "Fix that and come back to try again."
            exit 1
        fi
        WEBSOURCE="$WEBPATH/$SOURCE"
        echo -e "\nWhat device/directory name would you like to use for this installation?  Any"
        echo -e "character entered that is not [a-z], [0-9], - or _ will be converted to an"
        echo -e "underscore.  Alpha characters will be converted to lowercase.  Do not enter a"
        echo -e "full path, enter the name to be appended to the standard paths.\n"
        read -rp "Enter chamber name: " chamber < /dev/tty
        chamber="$(echo "$chamber" | sed -e 's/[^A-Za-z0-9._-]/_/g')"
        chamber="${chamber,,}"
        while [ -z "$chamber" ] || [ "$(checkchamber "$chamber")" == false ]
        do
            echo -e "\nError: Device/directory name blank or already exists."
            read -rp "Enter chamber name: " chamber < /dev/tty
            chamber="$(echo "$chamber" | sed -e 's/[^A-Za-z0-9._-]/_/g')"
            chamber="${chamber,,}"
        done
        CHAMBER="$chamber"
        SCRIPTPATH="/home/brewpi/$CHAMBER"
        echo -e "\nUsing '$SCRIPTPATH' for scripts directory."
    else
        # First install; give option to do multi-chamber
        echo -e "\nIf you would like to use BrewPi in multi-chamber mode, or simply not use the"
        echo -e "defaults for scripts and web pages, you may choose a name for sub directory and"
        echo -e "devices now.  Any character entered that is not [a-z], [0-9], - or _ will be"
        echo -e "converted to an underscore.  Alpha characters will be converted to lowercase."
        echo -e "Do not enter a full path, enter the name to be appended to the standard path.\n"
        echo -e "Enter device/directory name or hit enter to accept the defaults."
        read -rp "[<Enter> = Single chamber only]:  " chamber < /dev/tty
        if [ -z "$chamber" ]; then
            SCRIPTPATH="/home/brewpi"
        else
            chamber="$(echo "$chamber" | sed -e 's/[^A-Za-z0-9._-]/_/g')"
            CHAMBER="${chamber,,}"
            SCRIPTPATH="/home/brewpi/$CHAMBER"
        fi
        echo -e "\nUsing '$SCRIPTPATH' for scripts directory."
    fi
    
    if [ -n "$CHAMBER" ]; then
        echo -e "\nNow enter a friendly name to be used for the chamber as it will be displayed."
        echo -e "Capital letters may be used, however any character entered that is not [A-Z],"
        echo -e "[a-z], [0-9], - or _ will be replaced with an underscore. Spaces are allowed.\n"
        read -rp "[<Enter> = $CHAMBER]: " chamberName < /dev/tty
        if [ -z "$chamberName" ]; then
            CHAMBERNAME="$CHAMBER"
        else
            CHAMBERNAME="$(echo "$chamberName" | sed -e 's/[^A-Za-z0-9._-\ ]/_/g')"
        fi
        echo -e "\nUsing '$CHAMBERNAME' for chamber name."
    fi
}

############
### Install a udev rule to connect this instance to an Arduino
############

doport(){
    if [ -n "$CHAMBER" ]; then
        declare -i count=-1
        #declare -a port
        declare -a serial
        declare -a manuf
        rules="/etc/udev/rules.d/99-arduino.rules"
        devices=$(ls /dev/ttyACM* /dev/ttyUSB* 2> /dev/null)
        # Get a list of USB TTY devices
        for device in $devices; do
            declare ok=false
            # Walk device tree | awk out the stanza with the last device in chain
            board=$(udevadm info --a -n "$device" | awk -v RS='' '/ATTRS{maxchild}=="0"/')
            thisSerial=$(echo "$board" | grep "serial" | cut -d'"' -f 2)
            grep -q "$thisSerial" "$rules" 2> /dev/null || ok=true # Serial not in file
            [ -z "$board" ] && ok=false # Board exists
            if "$ok"; then
                ((count++))
                # Get the device Product ID, Vendor ID and Serial Number
                #idProduct=$(echo "$board" | grep "idProduct" | cut -d'"' -f 2)
                #idVendor=$(echo "$board" | grep "idVendor" | cut -d'"' -f 2)
                #port[count]="$device"
                serial[count]=$(echo "$board" | grep "serial" | cut -d'"' -f 2)
                manuf[count]=$(echo "$board" | grep "manufacturer" | cut -d'"' -f 2)
            fi
        done
        # Display a menu of devices to associate with this chamber
        if [ "$count" -gt 0 ]; then
            # There's more than one (it's 0-based)
            echo -e "\nThe following seem to be the Arduinos available on this system:\n"
            for (( c=0; c<=count; c++ ))
            do
                echo -e "[$c] Manuf: ${manuf[c]}, Serial: ${serial[c]}"
            done
            echo
            while :; do
                read -rp "Please select an Arduino [0-$count] to associate with this chamber:  " board < /dev/tty
                [[ "$board" =~ ^[0-"$count"]+$ ]] || { echo "Please enter a valid choice."; continue; }
                if ((board >= 0 && board <= count)); then
                    break
                fi
            done
            # Device already exists - well-meaning user may have set it up
            if [ -L "/dev/$CHAMBER" ]; then
                echo -e "\nPort /dev/$CHAMBER already exists as a link; using it but check your setup."
            else
                echo -e "\nCreating rule for board ${serial[board]} as /dev/$CHAMBER."
                # Concatenate the rule
                rule='SUBSYSTEM=="tty", ATTRS{serial}=="sernum", SYMLINK+="chambr"'
                #rule+=', GROUP="brewpi"'
                # Replace placeholders with real values
                rule="${rule/sernum/${serial[board]}}"
                rule="${rule/chambr/$CHAMBER}"
                echo "$rule" >> "$rules"
            fi
            udevadm control --reload-rules
            udevadm trigger
            elif [ "$count" -eq 0 ]; then
            # Only one (it's 0-based), use it
            if [ -L "/dev/$CHAMBER" ]; then
                echo -e "\nPort /dev/$CHAMBER already exists as a link; using it but check your setup."
            else
                echo -e "\nCreating rule for board ${serial[0]} as /dev/$CHAMBER."
                # Concatenate the rule
                rule='SUBSYSTEM=="tty", ATTRS{serial}=="sernum", SYMLINK+="chambr"'
                #rule+=', GROUP="brewpi"'
                # Replace placeholders with real values
                rule="${rule/sernum/${serial[0]}}"
                rule="${rule/chambr/$CHAMBER}"
                echo "$rule" >> "$rules"
            fi
            udevadm control --reload-rules
            udevadm trigger
        else
            # We have selected multi-chamber but there's no devices
            echo -e "\nYou've configured the system for multi-chamber support however no Arduinos were"
            echo -e "found to configure. The following configuration will be created, however you"
            echo -e "must manually create a rule for your device to match the configuration file."
            echo -e "\n\tConfiguration File: $SCRIPTPATH/settings/config.cnf"
            echo -e "\tDevice:             /dev/$CHAMBER\n"
            read -n 1 -s -r -p "Press any key to continue. "  < /dev/tty
            echo -e ""
        fi
    else
        echo -e "\nScripts will use default 'port = auto' setting."
    fi
}

############
### Backup existing scripts directory
############

backupscript() {
    local backupdir dirName
    # Back up installpath if it has any files in it
    if [ -d "$SCRIPTPATH" ] && [ -n "$(ls -A "${SCRIPTPATH}")" ]; then
        # Set place to put backups
        backupdir="$HOMEPATH/$GITPROJ-backup"
        dirName="$backupdir/$(date +%F%k:%M:%S)-Script"
        echo -e "\nScript install directory is not empty, backing up thisdirectory to"
        echo -e "'$dirName' and then deleting contents."
        mkdir -p "$dirName"
        cp -R "$SCRIPTPATH" "$dirName"/||die
        rm -rf "${SCRIPTPATH:?}"||die
        find "$SCRIPTPATH"/ -name '.*' -print0 | xargs -0 rm -rf||die
    fi
}

############
### Create/configure user account
############

makeuser() {
    echo -e "\nCreating and configuring accounts."
    if ! id -u brewpi >/dev/null 2>&1; then
        useradd brewpi -m -G dialout,www-data||die
    fi
    # Add current user to www-data & brewpi group
    usermod -a -G www-data,brewpi "$SUDO_USER"||die
}

############
### Clone BrewPi scripts
############

clonescripts() {
    local sourceURL
    echo -e "\nCloning BrewPi scripts to $SCRIPTPATH."
    # Clean out install path
    rm -fr "$SCRIPTPATH" >/dev/null 2>&1
    if [ ! -d "$SCRIPTPATH" ]; then mkdir -p "$SCRIPTPATH"; fi
    chown -R brewpi:brewpi "$SCRIPTPATH"||die
    if [ -n "$SOURCE" ]; then
        # Clone from local
        eval "sudo -u brewpi git clone -b $GITBRNCH $scriptSource $scriptPath"||die
        # Update $SCRIPTPATH with git origin from $SCRIPTSOURCE
        sourceURL="$(cd "$SCRIPTSOURCE" && git config --get remote.origin.url)"
        (cd "$SCRIPTPATH" && git remote set-url origin "$sourceURL")
    else
        # Clone from GitHub
        eval "sudo -u brewpi git clone -b $GITBRNCH --single-branch $GITURLSCRIPT $scriptPath"||die
    fi
}

############
### Install dependencies
############

dodepends() {
    chmod +x "$SCRIPTPATH/utils/doDepends.sh"
    eval "$SCRIPTPATH/utils/doDepends.sh"||die
}

############
### Web path setup
############

getwwwpath() {
    # Find web path based on Apache2 config
    echo -e "\nSearching for default web location."
    WEBPATH="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* |xargs |cut -d " " -f2)"
    if [ -n "$WEBPATH" ]; then
        echo -e "\nFound $WEBPATH in /etc/apache2/sites-enabled/000-default*."
    else
        echo "Something went wrong searching for /etc/apache2/sites-enabled/000-default*."
        echo "Fix that and come back to try again."
        exit 1
    fi
    # Use chamber name if configured
    if [ -n "$CHAMBER" ]; then
        WEBPATH="$WEBPATH/$CHAMBER"
    fi
    # Create web path if it does not exist
    if [ ! -d "$WEBPATH" ]; then mkdir -p "$WEBPATH"; fi
    chown -R www-data:www-data "$WEBPATH"||die
    echo -e "\nUsing '$WEBPATH' for web directory."
}

############
### Back up WWW path
############

backupwww() {
    local backupdir dirName rootWeb
    # Back up WEBPATH if it has any files in it
    rootWeb="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* |xargs |cut -d " " -f2)"
    /etc/init.d/apache2 stop||die
    rm -f "$WEBPATH/do_not_run_brewpi" 2> /dev/null || true
    rm -f "$rootWeb/index.html" 2> /dev/null || true
    if [ -d "$WEBPATH" ] && [ -n "$(ls -A "${WEBPATH}")" ]; then
        dirName="$backupdir/$(date +%F%k:%M:%S)-WWW"
        echo -e "\nWeb directory is not empty, backing up the web directory to:"
        echo -e "'$dirName' and then deleting contents of web directory."
        mkdir -p "$dirName"
        cp -R "$WEBPATH" "$dirName"/||die
        rm -rf "${WEBPATH:?}"||die
        find "$WEBPATH"/ -name '.*' -print0 | xargs -0 rm -rf||die
    fi
}

############
### Clone the web app
############

clonewww() {
    local sourceURL
    echo -e "\nCloning web site to $WEBPATH."
    if [ -n "$SOURCE" ]; then
        eval "sudo -u www-data git clone -b $GITBRNCH --single-branch $WEBSOURCE $WEBPATH"||die
        # Update $WEBPATH with git origin from $WEBSOURCE
        sourceURL="$(cd "$WEBSOURCE" && git config --get remote.origin.url)"
        (cd "$WEBPATH" && git remote set-url origin "$sourceURL")
    else
        eval "sudo -u www-data git clone -b $GITBRNCH --single-branch $GITURLWWW $WEBPATH"||die
    fi
    # Keep BrewPi from running while we do things
    touch "$WEBPATH/do_not_run_brewpi"
}

###########
### See if we are running Tilt/Tiltbridge/iSpindel
##########

doGravity() {
    local colors color i tiltColor
    colors=("Red" "Green" "Black" "Purple" "Orange" "Blue" "Yellow" "Pink")
    echo -e "" > /dev/tty
    read -rp "Would you like to add a Tilt to your configuration? [y/N]: " yn  < /dev/tty
    case "$yn" in
        [Yy]* )
            GRAVITY="true"
            i=0
            echo -e "\nWhat color Tilt are you using?\n" > /dev/tty
            for color in "${colors[@]}";
            do
                ((i++))
                echo -e "\t[$i]\t$color"
            done
            echo -e "" > /dev/tty
            read -rp "Select 1-$i: " tiltColor  < /dev/tty
            while [[ -z "$tiltColor" || "$tiltColor" -lt 1 || "$tiltColor" -gt "$i" ]]
            do
                read -rp "Select 1-$i: " tiltColor  < /dev/tty
            done
            ((tiltColor--))
            ;;
        * ) ;;
    esac
    TILTCOLOR="${colors[$tiltColor]}"
}

###########
### If non-default paths are used, create/update configuration files accordingly
##########

updateconfig() {
    local port
    if [ -n "$CHAMBER" ] || [ -n $GRAVITY ]; then
        echo -e "\nCreating custom configurations for $CHAMBER."
        # Create script path in custom script configuration file
        echo "scriptPath = $SCRIPTPATH" >> "$SCRIPTPATH/settings/config.cfg"
        # Create web path in custom script configuration file
        echo "wwwPath = $WEBPATH" >> "$SCRIPTPATH/settings/config.cfg"
        # Create port name in custom script configuration file
        if [ -z "$CHAMBER" ]; then
            port="auto"
        else
            port="/dev/$CHAMBER"
        fi
        echo "port = $port" >> "$SCRIPTPATH/settings/config.cfg"
        # Create chamber name in custom script configuration file
        echo "chamber = \"$CHAMBERNAME\"" >> "$SCRIPTPATH/settings/config.cfg"
        # Create Tilt name in custom script configuration file
        if [ -n $TILTCOLOR ]; then
            echo "tiltColor = $TILTCOLOR" >> "$SCRIPTPATH/settings/config.cfg"
        fi
        # Create script path in custom web configuration file
        echo "<?php " >> "$WEBPATH"/config_user.php
        echo "\$scriptPath = '$SCRIPTPATH';" >> "$WEBPATH/config_user.php"
    fi
}

############
### Fix permissions
############

doperms() {
    chmod +x "$SCRIPTPATH/utils/doPerms.sh"
    eval "$SCRIPTPATH/utils/doPerms.sh"||die
}

############
### Install daemons
############

dodaemon() {
    touch "$WEBPATH/do_not_run_brewpi" # make sure BrewPi does not start yet
    chmod +x "$SCRIPTPATH/utils/doDaemon.sh"
    # Get wireless lan device name
    WLAN="$(iw dev | awk '$1=="Interface"{print $2}')"
    # If no WLAN or if we are cloning from a local git
    if [ -n "$SOURCE" ] || [ -z $WLAN ]; then
        eval "$SCRIPTPATH/utils/doDaemon.sh -nowifi"||die
    else
        eval "$SCRIPTPATH/utils/doDaemon.sh"||die
    fi
    if [ -n "$CHAMBER" ]; then
        systemctl stop "$CHAMBER"
    else
        systemctl stop brewpi
    fi
}

############
### Fix an issue with BrewPi and Safari-based browsers
############

fixsafari() {
    echo -e "\nFixing apache2.conf."
    sed -i -e 's/KeepAliveTimeout 5/KeepAliveTimeout 99/g' /etc/apache2/apache2.conf
    /etc/init.d/apache2 restart
}

############
### Flash controller
############

flash() {
    local yn branch
    branch="${GITBRNCH,,}"
    if [ ! "$branch" == "master" ]; then
        branch="--beta"
    else
        branch=""
    fi
    echo -e "\nIf you have previously flashed your controller, you do not need to do so again."
    read -rp "Do you want to flash your controller now? [y/N]: " yn  < /dev/tty
    case "$yn" in
        [Yy]* ) eval "python -u $SCRIPTPATH/utils/updateFirmware.py $branch" ;;
        * ) ;;
    esac
}

############
### Print final banner
############

complete() {
    clear
    local sp7 sp11 sp18 sp28 sp49 IP
    sp7="$(printf ' %.0s' {1..7})" sp11="$(printf ' %.0s' {1..11})"
    sp18="$(printf ' %.0s' {1..18})" sp28="$(printf ' %.0s' {1..28})"
    sp49="$(printf ' %.0s' {1..49})"
    IP=$(ip -4 addr | grep 'global' | cut -f1  -d'/' | cut -d" " -f6)
    # Note:  $(printf ...) hack adds spaces at beg/end to support non-black BG
  cat << EOF

$DOT$BGBLK$FGYLW$sp7 ___         _        _ _    ___                _     _$sp18
$DOT$BGBLK$FGYLW$sp7|_ _|_ _  __| |_ __ _| | |  / __|___ _ __  _ __| |___| |_ ___ $sp11
$DOT$BGBLK$FGYLW$sp7 | || ' \(_-<  _/ _\` | | | | (__/ _ \ '  \| '_ \ / -_)  _/ -_)$sp11
$DOT$BGBLK$FGYLW$sp7|___|_||_/__/\__\__,_|_|_|  \___\___/_|_|_| .__/_\___|\__\___|$sp11
$DOT$BGBLK$FGYLW$sp49|_|$sp28
$DOT$BGBLK$FGGRN$HHR$RESET
BrewPi scripts will start shortly, usually within 30 seconds.

 - BrewPi frontend URL : http://$IP/$CHAMBER
                  -or- : http://$(hostname).local/$CHAMBER
 - Installation path   : $SCRIPTPATH
 - Release version     : $VERSION ($GITBRNCH)
 - Commit version      : $COMMIT
 - Install tools path  : $TOOLPATH
EOF
    if [ -n "$CHAMBER" ]; then
    cat << EOF
 - Multi-chamber URL   : http://$IP
                  -or- : http://$(hostname).local

If you would like to install another chamber, issue the command:
sudo $TOOLPATH/install.sh
EOF
    fi
    echo -e "\nHappy Brewing!"
}

############
### Main
############

# TODO:  Make decisions to do things based on [ ! -z "$INSTANCES" ] (true if multichamber)

main() {
    init "$@" # Initialize constants and variables
    checkroot "$@" # Make sure we are using sudo
    [[ "$*" == *"-verbose"* ]] && VERBOSE=true # Do not trim logs
    log "$@" # Create installation log
    arguments "$@" # Handle command line arguments
    echo -e "\n***Script $THISSCRIPT starting.***"
    term # Provide term codes
    findbrewpi # See if BrewPi is already installed
    [ -z "$SOURCE" ] && checknet # Check for connection to GitHub
    checkfree # Make sure there's enough free space for install
    getscriptpath # Choose a sub directory name or take default for scripts
    doport # Install a udev rule for the Arduino connected to this installation
    backupscript # Backup anything in the scripts directory
    makeuser # Create/configure user account
    clonescripts # Clone scripts git repository
    [ -z "$SOURCE" ] && dodepends # Install dependencies
    getwwwpath # Get WWW install location
    backupwww # Backup anything in WWW location
    clonewww # Clone WWW files
    doGravity # Check if we are running a Tilt/Tiltbridge/iSpindel
    updateconfig # Update config files if non-default paths are used
    dodaemon # Set up daemons
    fixsafari # Fix display bug with Safari browsers
    # Add links for multi-chamber dashboard
    if [ -n "$CHAMBER" ]; then
        webRoot="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* |xargs |cut -d " " -f2)"
        if [ ! -L "$webRoot/index.php" ]; then
            eval "$SCRIPTPATH/utils/doIndex.sh"||warn
        fi
    fi
    doperms # Set script and www permissions
    flash # Flash controller
    # Allow BrewPi to start via daemon
    rm -f "$WEBPATH/do_not_run_brewpi"
    if [ -n "$CHAMBER" ]; then
        systemctl start "$CHAMBER"
    else
        systemctl start brewpi
    fi
    complete # Cleanup and display instructions
}

############
### Start the script
############

main "$@" && exit 0
