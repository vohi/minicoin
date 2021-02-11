#!/bin/bash

/usr/local/bin/brew install --cask osxfuse
/usr/local/bin/brew install sshfs

if ( ! sudo grep "minicoin" /etc/synthetic.conf )
then
    echo -e 'minicoin\t/System/Volumes/Data/private/tmp/vagrant-minicoin' | sudo tee -a /etc/synthetic.conf
fi

# force the system integrity check to pop up
echo vagrant | /usr/local/bin/sshfs -o password_stdin,allow_other,defer_permissions,cache=no,StrictHostKeyChecking=no vagrant@127.0.0.1:/ home_mount
umount home_mount
rm -r home_mount

exit 0
