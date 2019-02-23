#!/bin/bash

declare -i count=-1
declare -a port
declare -a serial
declare -a manuf
devices=$(ls /dev/ttyACM* /dev/ttyUSB* /dev/rfcomm* 2> /dev/null)
# Get a list of USB and BT TTY devices
for device in $devices; do
  # Walk device tree | awk out the stanza with the last device in chain
  board=$(udevadm info --a -n $device | awk -v RS='' '/ATTRS{maxchild}=="0"/')
  thisSerial=$(echo "$board" | grep "serial" | cut -d'"' -f 2)
  ((count++))
  # Get the device Product ID, Vendor ID and Serial Number
  port[count]="$device"
  serial[count]=$(echo "$board" | grep "serial" | cut -d'"' -f 2)
  manuf[count]=$(echo "$board" | grep "manufacturer" | cut -d'"' -f 2)
done
# Display a menu of devices to associate with this chamber
echo -e "\nThe following seem to be the ancillary tty device(s) available on this system:\n"
for (( c=0; c<=count; c++ ))
do
  echo -e "Manuf: ${manuf[c]}, Serial: ${serial[c]} on ${port[c]}."
done
