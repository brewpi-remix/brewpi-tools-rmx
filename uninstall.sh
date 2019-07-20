#!/bin/bash

# Copyright (C) 2018, 2019 Lee C. Bussy (@LBussy)

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
declare CMDLINE PACKAGE GITBRNCH THISSCRIPT VERSION APTPACKAGES NGINXPACKAGES
declare PIPPACKAGES REPLY REALUSER LINK
# Version/Branch Constants
GITBRNCH="master"
VERSION="0.5.3.1"
THISSCRIPT="uninstall.sh"
LINK="uninstall.brewpiremix.com"

############
### Init
############

init() {
    # Set up some project variables we won't have
    PACKAGE="BrewPi-Tools-RMX"
    if [ ! "GITBRNCH" == "master" ]; then
    # Use devel branch link
        CMDLINE="curl -L dev$LINK | sudo bash"
    else
        CMDLINE="curl -L $LINK | sudo bash"
    fi
    # Packages to be uninstalled via apt
    APTPACKAGES="git-core pastebinit build-essential git arduino-core libapache2-mod-php apache2 python-configobj python-dev python-pip php-xml php-mbstring php-cgi php-cli php-common php"
    # nginx packages to be uninstalled via apt if present
    NGINXPACKAGES="libgd-tools fcgiwrap nginx-doc ssl-cert fontconfig-config fonts-dejavu-core libfontconfig1 libgd3 libjbig0 libnginx-mod-http-auth-pam libnginx-mod-http-dav-ext libnginx-mod-http-echo libnginx-mod-http-geoip libnginx-mod-http-image-filter libnginx-mod-http-subs-filter libnginx-mod-http-upstream-fair libnginx-mod-http-xslt-filter libnginx-mod-mail libnginx-mod-stream libtiff5 libwebp6 libxpm4 libxslt1.1 nginx nginx-common nginx-full"
    # Packages to be uninstalled via pip
    PIPPACKAGES="pyserial psutil simplejson gitpython configobj"
}

############
### Handle logging
############

timestamp() {
    # Add date in '2019-02-26 08:19:22' format to log
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
    local thisscript scriptname realuser homepath shadow
    [[ "$*" == *"-nolog"* ]] && return # Don;t turn on logging
    # Explicit scriptname (creates log name) since we start
    # before the main script
    thisscript="uninstall.sh"
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
    local shadow retval
    if [ -n "$SUDO_USER" ]; then REALUSER="$SUDO_USER"; else REALUSER=$(whoami); fi
    if [[ "$EUID" -ne 0 ]]; then
        sudo -n true 2> /dev/null
        local retval="$?"
        if [ "$retval" -eq 0 ]; then
            echo -e "\nNot running as root, relaunching correctly.\n"
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
        HOMEPATH=$(echo "$shadow" | cut -d':' -f6)
    else
        echo -e "\nUnable to retrieve $REALUSER's home directory. Manual install may be necessary."
        exit 1
    fi
}

############
### Handle the do_not_run files
############

create_donotrun() {
    local webroot chamberdir instance instances
    # Do our best here - we have no idea where the web root may be
    webroot="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* 2>/dev/null |xargs |cut -d " " -f2)"
    if [ -z "$webroot" ]; then
        # Make a decent guess
        if [ -d "/var/www/html" ]; then
            webroot="/var/www/html"
        else
            webroot="/var/www"
        fi
    fi
    instances=$(find "$webroot" -name "beer-panel.php" 2> /dev/null)
    IFS=$'\n' instances=("$(sort <<<"${instances[*]}")") && unset IFS # Sort list
    for instance in $instances
    do
        chamberdir=$(dirname "${instance}")
        touch "$chamberdir/do_not_run_brewpi" > /dev/null 2>&1
    done
}

############
### Remove cron for brewpi
############

cron() {
    # Clear out the old brewpi cron if it exists
    if [ -f /etc/cron.d/brewpi ]; then
        echo -e "\nResetting cron." > /dev/tty
        rm -f /etc/cron.d/brewpi
        /etc/init.d/cron restart
    fi
}

############
### Remove syslogd unit files for brewpi and wificheck
############

syslogd() {
    local ddir targets target filename name
    ddir="/etc/systemd/system"
    targets="$(grep -rl "# Created for BrewPi version" $ddir)"
    
    for target in $targets
    do
        filename="$(basename "$target")"
        name="$(basename -s ".service" "$target")"
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
### Stop all BrewPi processes the right way
############

quitproc() {
    declare home instance instances
    home="/home/brewpi"
    echo -e "\nQuitting any running BrewPi processes." > /dev/tty
    instances=$(find "$home" -name "brewpi.py" 2> /dev/null)
    IFS=$'\n' instances=("$(sort <<<"${instances[*]}")") && unset IFS # Sort list
    # Send quit messages to all BrewPi instances
    for instance in $instances
    do
        /usr/bin/python -u "$instance" --quit
    done
    sleep 2
    # Get instances again
    echo -e "\nKilling any running BrewPi processes." > /dev/tty
    instances=$(find "$home" -name "brewpi.py" 2> /dev/null)
    IFS=$'\n' instances=("$(sort <<<"${instances[*]}")") && unset IFS # Sort list    # Send kill messages to all BrewPi instances
    for instance in $instances
    do
        /usr/bin/python -u "$instance" --kill
    done
    sleep 2
}

############
### Stop all BrewPi processes the hard way
############

killproc() {
    # Kill all brewpi.py processes owned by brewpi - one way or another
    local pidlist pid
    if [ -n "$(getent passwd brewpi)" ]; then
        pidlist=$(pgrep -u brewpi -i -a python | grep -i brewpi.py)
    fi
    for pid in $pidlist
    do
        # Stop (kill) brewpi
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "\nAttempting graceful shutdown of process $pid."
            kill -15 "$pid"
            sleep 2
            if ps -p "$pid" > /dev/null 2>&1; then
                echo -e "\nTrying a little harder to terminate process $pid."
                kill -2 "$pid"
                sleep 2
                if ps -p "$pid" > /dev/null 2>&1; then
                    echo -e "\nBeing more forceful with process $pid."
                    kill -1 "$pid"
                    sleep 2
                    while ps -p "$pid" > /dev/null 2>&1;
                    do
                        echo -e "\nBeing really insistent about killing process $pid now."
                        echo -e "(I'm going to keep doing this till the process(es) are gone.)"
                        kill -9 "$pid"
                        sleep 2
                    done
                fi
            fi
        fi
    done
}

############
### Remove all BrewPi repositories
############

delrepo() {
    local webroot
    # Wipe out tools
    if [ -d "/home/$REALUSER/brewpi-tools-rmx" ]; then
        echo -e "\nClearing /home/$REALUSER/brewpi-tools-rmx." > /dev/tty
        rm -fr "/home/$REALUSER/brewpi-tools-rmx"
    fi
    # Wipe out legacy tools
    if [ -d "/home/$REALUSER/brewpi-tools" ]; then
        echo -e "\nClearing /home/$REALUSER/brewpi-tools." > /dev/tty
        rm -fr "/home/$REALUSER/brewpi-tools"
    fi
    # Wipe out BrewPi scripts
    if [ -d /home/brewpi ]; then
        echo -e "\nClearing /home/brewpi." > /dev/tty
        rm -fr /home/brewpi
    fi
    # Wipe out www if it exists and is not empty
    webroot="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* 2>/dev/null |xargs |cut -d " " -f2)"
    if [ -z "$webroot" ]; then
        # Make a decent guess
        if [ -d "/var/www/html" ]; then
            webroot="/var/www/html"
        else
            webroot="/var/www"
        fi
    fi
    if [ -n "$(ls -A "$webroot")" ]; then
        echo -e "\nClearing $webroot." > /dev/tty
        rm -fr "$webroot"
        # Re-create html durectory
        mkdir "$webroot"
        chown www-data:www-data "$webroot"
    fi
}

############
### Remove brewpi user/group
############

cleanusers() {
    local retval realuser username
    # Cleanup real user membership
    if [ -n "$SUDO_USER" ]; then realuser="$SUDO_USER"; else realuser=$(whoami); fi
    echo -e "\nCleaning up group membership for $realuser."
    if getent group brewpi | grep &>/dev/null "\b${realuser}\b"; then
        deluser "$realuser" brewpi &>/dev/null
    fi
    if getent group www-data | grep &>/dev/null "\b${realuser}\b"; then
        deluser "$realuser" www-data &>/dev/null
    fi
    # Cleanup www-data user membership
    username="www-data"
    echo -e "\nCleaning up group membership for $username."
    if getent group brewpi | grep &>/dev/null "\b${username}\b"; then
        deluser "$username" brewpi &>/dev/null
    fi
    # Delete brewpi user
    username="brewpi"
    echo -e "\nCleaning up group membership for $username."
    if getent group www-data | grep &>/dev/null "\b${username}\b"; then
        deluser "$username" www-data &>/dev/null
    fi
    if id "$username" > /dev/null 2>&1; then
        echo -e "\nRemoving user $username." > /dev/tty
        userdel "$username" &>/dev/null
    fi
    grep -E "^$username" /etc/group;
    retval="$?"
    if [ "$retval" -eq 0 ]; then
        groupdel "$username" &>/dev/null
    fi
}

############
### Reset Apache
############

resetapache() {
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

delpip() {
    local retval pkg pipInstalled
    echo -e "\nChecking for pip packages installed with BrewPi." > /dev/tty
    if pip &>/dev/null; then
        pipInstalled=$(pip list --format=legacy)
        retval="$?"
        if [ "$retval" -eq 0 ]; then
            pipInstalled=$(echo "$pipInstalled" | awk '{ print $1 }')
            for pkg in ${PIPPACKAGES,,}; do
                if [[ ${pipInstalled,,} == *"$pkg"* ]]; then
                    echo -e "\nRemoving '$pkg'.\n" > /dev/tty
                    pip uninstall "$pkg" -y
                fi
            done
        fi
    fi
}

############
### Remove apt packages
############

delapt() {
    local pkg packagesInstalled
    echo -e "\nChecking for apt packages installed with BrewPi." > /dev/tty
    # Get list of installed packages
    packagesInstalled=$(dpkg --get-selections | awk '{ print $1 }')
    # Loop through the required packages and uninstall those in $APTPACKAGES
    for pkg in ${APTPACKAGES,,}; do
        if [[ ${packagesInstalled,,} == *"$pkg"* ]]; then
            echo -e "\nRemoving '$pkg'.\n" > /dev/tty
            apt-get remove --purge "$pkg" -y
        fi
    done
}

############
### Remove php5 packages if installed
############

delphp5() {
    local pkg php5packages yn
    echo -e "\nChecking for previously installed php5 packages." > /dev/tty
    # Get list of installed packages
    php5packages="$(dpkg --get-selections | awk '{ print $1 }' | grep 'php5')"
    if [[ -z "$php5packages" ]] ; then
        echo -e "\nNo php5 packages found." > /dev/tty
    else
        echo -e "\nFound php5 packages installed.  It is recomended to uninstall all php before" > /dev/tty
        echo -e "proceeding as BrewPi requires php7 and will install it during the install" > /dev/tty
        read -rp "process.  Would you like to clean this up before proceeding?  [Y/n]: " yn  < /dev/tty
        case $yn in
            [Nn]* )
                echo -e "\nUnable to proceed with php5 installed, exiting." > /dev/tty;
            exit 1;;
            * )
                php_packages="$(dpkg --get-selections | awk '{ print $1 }' | grep 'php')"
                # Loop through the php5 packages that we've found
                for pkg in ${php_packages,,}; do
                    echo -e "\nRemoving '$pkg'.\n" > /dev/tty
                    apt-get remove --purge "$pkg" -y
                done
                echo -e "\nCleanup of the php environment complete." > /dev/tty
            ;;
        esac
    fi
}

############
### Remove nginx packages if installed
############

delnginx() {
    local nginxPackage yn pkg
    echo -e "\nChecking for previously installed nginx packages." > /dev/tty
    # Get list of installed packages
    nginxPackage="$(dpkg --get-selections | awk '{ print $1 }' | grep 'nginx')"
    if [[ -z "$nginxPackage" ]] ; then
        echo -e "\nNo nginx packages found." > /dev/tty
    else
        echo -e "\nFound nginx packages installed.  It is recomended to uninstall nginx before" > /dev/tty
        echo -e "proceeding as BrewPi requires apache2 and they will conflict with each other." > /dev/tty
        read -rp "Would you like to clean this up before proceeding?  [Y/n]: " yn  < /dev/tty
        case $yn in
            [Nn]* )
                echo -e "\nUnable to proceed with nginx installed, exiting." > /dev/tty;
            exit 1;;
            * )
                # Loop through the php5 packages that we've found
                for pkg in ${NGINXPACKAGES,,}; do
                    echo -e "\nRemoving '$pkg'.\n" > /dev/tty
                    apt-get remove --purge "$pkg" -y
                done
                echo -e "\nCleanup of the nginx environment complete." > /dev/tty
            ;;
        esac
    fi
}

############
### Cleanup local packages
############

cleanapt() {
    # Cleanup
    echo -e "\nCleaning up local apt packages." > /dev/tty
    apt-get autoremove --purge -y
    apt-get clean -y
    apt-get autoclean -y
}

############
### Reset hostname
###########

resethost() {
    local oldHostName newHostName sed1 sed2
    oldHostName=$(hostname)
    newHostName="raspberrypi"
    if [ "$oldHostName" != "$newHostName" ]; then
        echo -e "\nResetting hostname from $oldHostName back to $newHostName." > /dev/tty
        sed1="sed -i 's/$oldHostName/$newHostName/g' /etc/hosts"
        sed2="sed -i 's/$oldHostName/$newHostName/g' /etc/hostname"
        eval "$sed1"
        eval "$sed2"
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

resetudev() {
    local rules
    rules="/etc/udev/rules.d/99-arduino.rules"
    if [ -f "$rules" ]; then
        echo -e "\nRemoving udev rules." > /dev/tty
        rm "$rules"
        udevadm control --reload-rules
        udevadm trigger
    fi
}

############
### Reset pi password
###########

resetpwd() {
    if getent passwd "pi" > /dev/null; then
        echo -e "\nResetting password for 'pi' back to 'raspberry'." > /dev/tty
        echo "pi:raspberry" | chpasswd
    fi
}

############
### Process single chamber
############

delchamber() {
    local chamber newchamber link home instances newlink webDir unitFile
    local daemonName rules scriptDir webPath
    chamber="$1"
    home="/home/brewpi"
    rules="/etc/udev/rules.d/99-arduino.rules"
    # Get $chamber, $scriptDir and $webDir for uninstall
    scriptDir="$home/$chamber"
    webPath="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* | xargs | cut -d " " -f2)"
    if [ -z "$webPath" ]; then
        echo -e "\nSomething went wrong searching for /etc/apache2/sites-enabled/000-default*."
        echo -e "Fix that and come back to try again."
        exit 1
    fi
    webDir="$webPath/$chamber"
    unitFile="/etc/systemd/system/$chamber.service"
    daemonName="$chamber.service"
    
    # Check and fix symlink if needed
    echo
    link=$(dirname "$(readlink "$webPath/index.php")")
    if [ "$link" == "$webDir" ]; then
        echo -e "\nThis operation will delete the target of the multi-chamber index link."
        instances=$(find "$home" -name "brewpi.py" 2> /dev/null)
        for instance in $instances; do
            if [ ! "$(dirname "$instance")" == "$scriptDir" ]; then
                newchamber="$(basename "$(dirname "$instance")")"
                newlink="$webPath/$newchamber/multi-index.php"
                break
            fi
        done
        echo -e "\nReplacing multi-chamber symlink:"
        echo -e "Target: $newlink"
        echo -e "Link:   $webPath/index.php"
        ln -sfn "$newlink" "$webPath/index.php"
    fi
    
    # Delete daemon for chamber
    if [ -f "$unitFile" ]; then
        # TODO:  Delete unit file for that chamber
        echo -e "\nStopping $chamber daemon."
        systemctl stop "$daemonName"
        echo -e "Disabling $chamber daemon."
        systemctl disable "$daemonName"
        echo -e "Removing unit file for $chamber."
        rm "$unitFile" > /dev/null 2>&1
        systemctl daemon-reload
    fi
    # Delete BrewPi scripts for chamber
    if [ -d "$scriptDir" ]; then
        # Stop running instance
        "$scriptDir/brewpi.py --quit" > /dev/null 2>&1
        "$scriptDir/brewpi.py --kill" > /dev/null 2>&1
        # Remove BrewPi script instance
        echo -e "\nRemoving $scriptDir."
        rm -fr "$scriptDir" > /dev/null 2>&1
    fi
    # Delete BrewPi web for chamber
    if [ -d "$webDir" ]; then
        # TODO:  See if we have links pointed here
        # Remove BrewPi web instance
        echo -e "\nRemoving $webDir."
        rm -fr "$webDir" > /dev/null 2>&1
    fi
    # Delete device for chamber
    if [ -L "/dev/$chamber" ]; then
        # TODO:  Delete rule for that chamber
        echo -e "\nRemoving rule for /dev/$chamber."
        sed -i "/$chamber/d" "$rules" > /dev/null 2>&1
        udevadm control --reload-rules
        udevadm trigger
    fi
}

############
### Select a chamber
###########

numchamber() {
    local home instances
    home="/home/brewpi"
    instances=$(find "$home" -name "brewpi.py" 2> /dev/null)
    if [ ${#instances} -gt 22 ]; then
        arr=($instances)
        return $((${#arr[@]}))
    fi
    return 0
}

############
### Select a chamber
###########

getchamber() {
    local home idx arr re sel instances
    home="/home/brewpi"
    idx=0
    instances=$(find "$home" -name "brewpi.py" 2> /dev/null)
    IFS=$'\n' instances=("$(sort <<<"${instances[*]}")") && unset IFS # Sort list
    arr=($instances)
    if [ ${#instances} -gt 22 ]; then
        # Found multiple chambers
        echo -e "\nThe following chambers are configured on this device:\n" > /dev/tty
        for instance in $instances
        do
            echo -e "\t[$idx] $(dirname "${instance}")" > /dev/tty
            arr[$idx]="$(basename "$(dirname "${arr[$idx]}")")"
            ((idx++))
        done
        echo > /dev/tty
        read -r -s -n1 -p "Enter chamber to uninstall [0-$((${#arr[@]}-1))] or any other key to quit: " sel < /dev/tty
        re='^[0-9]+$'
        if [[ "$sel" =~ $re ]] ; then echo "${arr["$sel"]}"; fi
    else
        echo -e "\nNot configured for multi-chamber mode." > /dev/tty
    fi
}

############
### Choose uninstall level
###########

wipelevel () {
    local level retval
    echo -e "\nSelect the level of uninstall you wish to execute.  The least is level [1]" > /dev/tty
    echo -e "which is probably appropriate if you have an issue and are looking to cleanup" > /dev/tty
    echo -e "and reinstall.  Level [2] will reset the hostname and the password for 'pi'" > /dev/tty
    echo -e "back to 'raspberry.'  Level [3] is the most intense, adding the execution of" > /dev/tty
    echo -e "apt and pip package removals.  [3] is likely only appropriate for testers and" > /dev/tty
    echo -e "you should not run it unless you know what you are doing or someone tells you" > /dev/tty
    echo -e "that you need to.\n" > /dev/tty
    echo -e "   [1] - Normal uninstall of BrewPi repositories, services and devices" > /dev/tty
    echo -e "   [2] - Everything in [1] plus reset hostname and pi password" > /dev/tty
    echo -e "   [3] - Everything in [1] and [2] plus wipe pip and apt packages" > /dev/tty
    numchamber
    retval=$?
    if [[ $retval -gt 1 ]]; then
        echo -e "   [4] - Select a single chamber to uninstall\n" > /dev/tty
        while :
        do
            read -r -s -n1 -p "Enter level of uninstall to execute [1-4] or any other key to quit: " level < /dev/tty
            case "$level" in
                1 )
                    echo -e "\n\nExecuting a level one (mild) uninstall." > /dev/tty
                    echo 1
                break ;;
                2 )
                    echo -e "\n\nExecuting a level two (medium) uninstall." > /dev/tty
                    echo 2
                break ;;
                3 )
                    echo -e "\n\nExecuting a level three (hard) uninstall." > /dev/tty
                    echo 3
                break ;;
                4 )
                    echo -e "\n\nExecuting a selective uninstall." > /dev/tty
                    echo 4
                break ;;
                * )
                    echo -e "\n\nUninstall canceled." > /dev/tty
                    echo "Q"
                break ;;
            esac
        done
    else
        echo > /dev/tty
        while :
        do
            read -r -s -n1 -p "Enter level of uninstall to execute [1-3] or any other key to quit: " level < /dev/tty
            case "$level" in
                1 )
                    echo -e "\n\nExecuting a level one (mild) uninstall." > /dev/tty
                    echo 1
                break ;;
                2 )
                    echo -e "\n\nExecuting a level two (medium) uninstall." > /dev/tty
                    echo 2
                break ;;
                3 )
                    echo -e "\n\nExecuting a level three (hard) uninstall." > /dev/tty
                    echo 3
                break ;;
                * )
                    echo -e "\n\nUninstall canceled." > /dev/tty
                    echo "Q"
                break ;;
            esac
        done
    fi
}

############
### Main
###########

main() {
    log "$@" # Start logging
    init "$@" # Get constants
    arguments "$@" # Check command line arguments
    echo -e "\n***Script $THISSCRIPT starting.***" > /dev/tty
    checkroot # Check for root privs
    cd ~ || exit 1 # Start from home
    level="$(wipelevel)"
    if [ ! "$level" == "Q" ]; then
        if [ "$level" -eq 4 ]; then
            chamber=$(getchamber)
            if [ -n "$chamber" ]; then
                delchamber "$chamber"
            else
                echo -e "\nNo chambers installed or no chamber selected, exiting."
            fi
        else
            [ "$level" -ge 1 ] && create_donotrun # Stop all brewpi procs
            [ "$level" -ge 1 ] && cron # Clean up crontab
            [ "$level" -ge 1 ] && syslogd # Cleanup syslogd
            [ "$level" -ge 1 ] && quitproc # Quit all brewpi procs
            [ "$level" -ge 1 ] && killproc # Kill all brewpi procs
            [ "$level" -ge 1 ] && delrepo # Remove all the repos
            [ "$level" -ge 1 ] && cleanusers # Clean up users and groups
            [ "$level" -ge 1 ] && resetapache # Reset Apache config to stock
            [ "$level" -ge 3 ] && delpip # Remove pip packages
            [ "$level" -ge 3 ] && delapt # Remove apt dependencies
            [ "$level" -ge 1 ] && delphp5 # Remove php5 packages
            [ "$level" -ge 1 ] && delnginx # Remove nginx
            [ "$level" -ge 1 ] && cleanapt # Clean up apt packages locally
            [ "$level" -ge 2 ] && resethost # Reset hostname
            [ "$level" -ge 1 ] && resetudev # Remove udev rules
            [ "$level" -ge 2 ] && resetpwd # Reset pi password
        fi
        echo -e "\n***Script BrewPi Uninstaller complete.***" > /dev/tty
    fi
}

main "$@" && exit 0
