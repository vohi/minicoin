#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
shopt -s nullglob nocaseglob

# get list of available software updates, and if there are any, install them

echo "Checking for maintenance software updates"
sudo softwareupdate -l 2>&1 | sudo tee /var/log/minicoin_softwareupdate.log

if (grep "No new software available" /var/log/minicoin_softwareupdate.log)
then
    echo "No software updates found"
else
    echo "$(date +"%Y-%m-%d %T") packer installing software updates and rebooting" | sudo tee /var/log/install.log
    sudo softwareupdate --install --all --force --restart
    sleep 30
fi

exit 0
