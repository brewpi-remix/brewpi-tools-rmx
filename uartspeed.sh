#!/bin/bash

# Copyright (C) 2018 - 2020 Lee C. Bussy (@LBussy)
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

# See: 'original-license.md' for notes about the original project's
# license and credits.

############
### Set up script constants
############

THISSCRIPT="uartspeed.sh" # Don't change for dev
LINK="uartspeed.brewpiremix.com"
CMDLINE="curl -L $LINK | sudo bash"
INPUT="/usr/bin/btuart"
OUTPUT="btuart.bak"
SEARCHSTRING="\$HCIATTACH /dev/serial1 bcm43xx"

############
### Make sure command is running with sudo
############

asroot() {
    local retval shadow
    if [ -n "$SUDO_USER" ]; then REALUSER="$SUDO_USER"; else REALUSER=$(whoami); fi
    if [ "$REALUSER" == "root" ]; then
        # We're not gonna run as the root user
        echo -e "\nThis script may not be run from the root account, use 'sudo' instead."
        exit 1
    fi
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
        echo -e "\nUnable to retrieve $REALUSER's home directory. Manual work may be necessary."
        exit 1
    fi
}

backup() {
    cp "$INPUT" "$OUTPUT"
    echo "$INPUT backed up to $HOMEPATH/$OUTPUT."
}

update() {
    while IFS= read -r line
    do
        if [[ "$line" == *"$SEARCHSTRING"* ]]
        then
            baud=$(echo "$line" | tr -s ' ' | cut -d ' ' -f 4)
            eval sed -i 's/$baud/115200/g' "$INPUT"
        fi
    done < "$INPUT"
    echo "$INPUT updated."
}

reset_daemon() {
    echo "Restarting bluetooth."
    systemctl restart bluetooth
    echo "Bluetooth daemon restarted. Please restart any client scripts."
}

main {
    asroot
    backup
    update
    reset_daemon
}

main() && exit 0
