#!/bin/bash

cat << EOF

This is currently under investigation.  In the meantime the
following will get you to a different branch:

sudo /home/brewpi/utils/doUpdate.sh
sudo systemctl stop brewpi
cd /var/www/html
sudo git checkout devel
sudo git pull
cd /home/brewpi
sudo git checkout devel
sudo git pull
cd /home/pi/brewpi-tools-rmx
sudo git checkout devel
sudo git pull
cd ~
sudo /home/brewpi/utils/doPerms.sh
sudo systemctl start brewpi

EOF
