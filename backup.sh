#!/bin/bash

# Copyright (C) 2019 Lee C. Bussy (@LBussy)
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
declare THISSCRIPT VERSION GITBRNCH GITPROJ PACKAGE VERBOSE WWWPATH HOMEPATH
declare REPLY SOURCE SCRIPTPATH CMDLINE GITRAW GITHUB SCRIPTNAME
# Color/character codes
declare BOLD SMSO RMSO FGBLK FGRED FGGRN FGYLW FGBLU FGMAG FGCYN FGWHT FGRST
declare BGBLK BGRED BGGRN BGYLW BGBLU BGMAG BGCYN BGWHT BGRST DOT HHR LHR RESET

############
### Init
############

init() {
    # Set up some project variables we won't have running as a bootstrap
    PACKAGE="BrewPi-Tools-RMX"
    GITBRNCH="devel"
    THISSCRIPT="backup.sh"
    VERSION="0.5.2.1"
    CMDLINE="curl -L devbackup.brewpiremix.com | sudo bash"
    # These should stay the same
    GITRAW="https://raw.githubusercontent.com/lbussy"
    GITHUB="https://github.com/lbussy"
    # Cobble together some strings
    SCRIPTNAME="${THISSCRIPT%%.*}"
    GITPROJ="${PACKAGE,,}"
    GITHUB="$GITHUB/$GITPROJ.git"
    GITRAW="$GITRAW/$GITPROJ/$GITBRNCH/$THISSCRIPT"
}

############
### Handle logging
############

timestamp() {
    # Add date in '2019-02-26 08:19:22' format to log
    [[ "$VERBOSE" == "true" ]] && length=999 || length=60 # Allow full logging
    while read -r; do
        # Clean and trim line to 60 characters to allow for timestamp on one line
        REPLY="$(clean "$REPLY" $length)"
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
    # Explicit scriptname (creates log name) since we start
    # before the main script
    thisscript="backup.sh"
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
    exec > >(tee >(timestamp >> "$homepath/$scriptname.log")) 2>&1
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
### Make sure command is running with sudo
############

checkroot() {
    local retval shadow
    if [ -n "$SUDO_USER" ]; then REALUSER="$SUDO_USER"; else REALUSER=$(whoami); fi
    ### Check if we have root privs to run
    if [[ "$EUID" -ne 0 ]]; then
        sudo -n true 2> /dev/null
        retval="$?"
        if [ "$retval" -eq 0 ]; then
            echo -e "\nNot running as root, relaunching correctly."
            sleep 2
            eval "$CMDLINE"
            exit "$?"
        else
            # sudo not available, give instructions
            echo -e "\nThis script must be run with root privileges."
            echo -e "Enter the following command as one line:"
            echo -e "$CMDLINE" 1>&2
            exit 1
        fi
    fi
    # And get the user home directory
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
    echo -e "Execution NOT completed.\n" > /dev/tty
}

die() {
    local st
    st="$?"
    warn "$@"
    exit "$st"
}

############
### Instructions
############

instructions() {
    local any sp11 sp17 sp22
    sp11="$(printf ' %.0s' {1..11})" sp17="$(printf ' %.0s' {1..17})"
    sp22="$(printf ' %.0s' {1..22})"
    clear
    # Note:  $(printf ...) hack adds spaces at beg/end to support non-black BG
    # http://patorjk.com/software/taag/#p=display&f=Small&t=BrewPi%20Backup
    cat  > /dev/tty << EOF

$DOT$BGBLK$FGYLW$sp11 ___                ___ _   ___          _                           
$DOT$BGBLK$FGYLW$sp11| _ )_ _ _____ __ _| _ (_) | _ ) __ _ __| |___  _ _ __               
$DOT$BGBLK$FGYLW$sp11| _ \ '_/ -_) V  V /  _/ | | _ \/ _' / _| / / || | '_ \\              
$DOT$BGBLK$FGYLW$sp11|___/_| \___|\_/\_/|_| |_| |___/\__,_\__|_\_\\\_,_| .__/              
$DOT$BGBLK$FGYLW$sp11                                                 |_|                 
$DOT$BGBLK$FGGRN$HHR$RESET
You may be presented with some choices during pogram execution. Most
frequently you will see a 'yes or no' choice, with the default choice
capitalized like so: [y/N]. Default means if you hit <enter> without typing
anything, you will make the capitalized choice, i.e. hitting <enter> when you
see [Y/n] will default to 'yes.'

Yes/no choices are not case sensitive. However; passwords, system names and
install paths are. Be aware of this. There is generally no difference between
'y', 'yes', 'YES', 'Yes'; you get the idea. In some areas you are asked for a
path; the default/recommended choice is in braces like: [/home/brewpi].
Pressing <enter> without typing anything will take the default/recommended
choice.

EOF
    read -n 1 -s -r -p  "Press any key when you are ready to proceed. " < /dev/tty
    echo -e ""
}

############
### Web path setup
############

getwwwpath() {
    # Find web path based on Apache2 config
    echo -e "\nSearching for default web location." > /dev/tty
    WWWPATH="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* | xargs | cut -d " " -f2)"
    if [ -n "$WWWPATH" ]; then
        if [ -f "$WWWPATH/beer-panel.php" ]; then
            echo -e "Found $WWWPATH in /etc/apache2/sites-enabled/000-default*." > /dev/tty
            echo "$WWWPATH"
        fi
    else
        echo "Something went wrong searching for /etc/apache2/sites-enabled/000-default*." > /dev/tty
        echo "Fix that and come back to try again." > /dev/tty
        echo ""
    fi
}

############
### Check for an existing BrewPi installation
############

getbrewpipath() {
    echo -e "\nSearching for default BrewPi location." > /dev/tty
    SCRIPTPATH="/home/brewpi"
    if [ -f "$SCRIPTPATH/brewpi.py" ]; then
        echo "BrewPi found at $SCRIPTPATH/." > /dev/tty
        echo "$SCRIPTPATH"
    else
        echo ""
    fi
}

############
### Banner in/out
############

banner() {
    local action
    action="$1"
    echo -e "\n***Script $THISSCRIPT $action.***" > /dev/tty
}

############
### Stop all BrewPi processes
############

killproc() {
    local SCRIPTPATH WWWPATH
    SCRIPTPATH=$1
    WWWPATH=$2
    if [ $(getent passwd brewpi) ]; then
        pidlist=$(pgrep -u brewpi python)
    fi
    echo -e "\nStopping BrewPi." > /dev/tty
    for pid in "$pidlist"
    do
        # Stop (kill) brewpi
        touch "$WWWPATH/do_not_run_brewpi" > /dev/null 2>&1
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
### Restart BrewPi processes
############

allowrun() {
    local SCRIPTPATH WWWPATH
    SCRIPTPATH=$1
    WWWPATH=$2
    echo -e "\nRemoving semaphore and allowing BrewPi to restart."
    rm -f "$WWWPATH/do_not_run_brewpi" > /dev/null 2>&1
}

############
### Do Backup
############

doBackup() {
    local HOMEPATH SCRIPTPATH WWWPATH DT ARCHIVE
    HOMEPATH="$1"
    SCRIPTPATH="$2"
    WWWPATH="$3"
    BACKUPDIR="$HOMEPATH/brewpi-backup"
    SCRIPTBACKUP="$BACKUPDIR/scripts"
    WWWBACKUP="$BACKUPDIR/www"
    DT=$(date +"%Y%m%dT%H%M%S")
    ARCHIVE="$HOMEPATH/$DT-brewpi-backup.zip"

    # Create directories
    echo -e "\nCreating backup directories." > /dev/tty
    mkdir -p "$SCRIPTBACKUP/data"
    mkdir -p "$SCRIPTBACKUP/settings"
    mkdir -p "$WWWBACKUP/data"
    
    # Rough backup of all settings and data
    echo -e "\nBacking up all settings and data." > /dev/tty
    [[ -e "$SCRIPTPATH/data" ]] && cp -ur "$SCRIPTPATH/data" "$SCRIPTBACKUP/"
    [[ -e "$SCRIPTPATH/settings/config.cfg" ]] && cp -u "$SCRIPTPATH/settings/config.cfg" "$SCRIPTBACKUP/settings/config.cfg"
    [[ -e "$WWWPATH/data" ]] && cp -ur "$WWWPATH/data" "$WWWBACKUP/"
    [[ -e "$WWWPATH/config_user.php" ]] && cp -u "$WWWPATH/config_user.php" "$WWWBACKUP/config_user.php"
    [[ -e "$WWWPATH/userSettings.json" ]] && cp -u "$WWWPATH/userSettings.json" "$WWWBACKUP/userSettings.json"

    # Change permissions
    echo -e "\nFixing file permissions for $BACKUPDIR." > /dev/tty
    chown -R "$REALUSER":"$REALUSER" "$BACKUPDIR"||warn
    chown -R "$REALUSER":"$REALUSER" "$WWWBACKUP"||warn
    find "$WWWBACKUP" -type d -exec chmod 2770 {} \; || warn
    find "$WWWBACKUP" -type f -exec chmod 640 {} \;||warn
    find "$WWWBACKUP/data" -type f -exec chmod 660 {} \;||warn
    find "$WWWBACKUP" -type f -name "*.json" -exec chmod 660 {} \;||warn
    chown -R "$REALUSER":"$REALUSER" "$SCRIPTBACKUP"||warn
    find "$SCRIPTBACKUP" -type d -exec chmod 775 {} \;||warn
    find "$SCRIPTBACKUP" -type f -exec chmod 660 {} \;||warn
    find "$SCRIPTBACKUP" -type f -regex ".*\.\(py\|sh\)" -exec chmod 770 {} \;||warn
    find "$SCRIPTBACKUP"/settings -type f -exec chmod 664 {} \;||warn

    # Cleanout stuff we don't need
    echo -e "\nRemoving sample data from backup set." > /dev/tty
    [[ -e "$SCRIPTBACKUP/data/Sample Data/" ]] && rm -fr "$SCRIPTBACKUP/data/Sample Data/"
    [[ -e "$SCRIPTBACKUP/data/Sample Data/" ]] && rm -fr "$SCRIPTBACKUP/data/Sample Data/"
    [[ -e "$SCRIPTBACKUP/data/Sample Data/" ]] && rm -fr "$SCRIPTBACKUP/data/Sample Data/"
    [[ -e "$WWWBACKUP/data/profiles/Sample Profile.csv" ]] && rm -fr "$WWWBACKUP/data/profiles/Sample Profile.csv"
    [[ -e "$WWWBACKUP/data/Sample Data/" ]] && rm -fr "$WWWBACKUP/data/Sample Data/"
    find "$BACKUPDIR" -name ".gitignore" -print0 | xargs -0 rm -rf
    find "$BACKUPDIR" -name "README.md" -print0 | xargs -0 rm -rf

    # Make a zip archive
    echo -e "\nCreating zip archive from backup set." > /dev/tty
    zip -r "$ARCHIVE" "$HOMEPATH/brewpi-backup" > /dev/null
    # And remove temp files
    rm -fr "$HOMEPATH/brewpi-backup/"

    # Return filename
    echo "$ARCHIVE"
}

############
### Main function
############

main() {
    local retVal
    [[ "$*" == *"-verbose"* ]] && VERBOSE=true # Do not trim logs
    log "$@" # Start logging
    init "$@" # Get constants
    arguments "$@" # Check command line arguments
    banner "starting"
    checkroot "$@" # Make sure we are su into root
    term "$@" # Add term command constants
    instructions "$@" # Show instructions
    WWWPATH=$(getwwwpath "$@") # Get path to WWW files
    SCRIPTPATH=$(getbrewpipath "$@") # Check path to BrewPi files
    if [ -n "$HOMEPATH" ] && [ -n "$WWWPATH" ] && [ -n "$SCRIPTPATH" ]; then
        killproc "$SCRIPTPATH" "$WWWPATH"
        retVal=$(doBackup "$HOMEPATH" "$SCRIPTPATH" "$WWWPATH")
        if [ -n "$retVal" ]; then
            echo -e "\nCreated backup in $retVal."
        else
            echo -e "\nUnable to create backup archive."
        fi
    else
        echo -e "\nUnable to determine BrewPi environment."
    fi
    allowrun "$SCRIPTPATH" "$WWWPATH"
    banner "complete"
}

############
### Start the script
############

main "$@" && exit 0
