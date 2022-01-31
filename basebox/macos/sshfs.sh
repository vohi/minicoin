#!/bin/bash

/usr/local/bin/brew install --cask osxfuse
/usr/local/bin/brew install sshfs

# force the system integrity check to pop up
echo vagrant | /usr/local/bin/sshfs -o password_stdin,allow_other,defer_permissions,cache=no,StrictHostKeyChecking=no vagrant@127.0.0.1:/ home_mount
umount home_mount
rm -r home_mount

exit 0
