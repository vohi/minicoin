#!/bin/bash
set -euo pipefail

if (! sudo cat /etc/sudoers)
then
    echo vagrant | sudo -S bash -c "echo \"vagrant\tALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers"
fi

# allow software from anyone
sudo spctl --global-disable
spctl developer-mode enable-terminal
