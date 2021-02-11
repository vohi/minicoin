#!/bin/bash

/usr/local/bin/brew cleanup --prune=all
/usr/local/bin/brew autoremove

# stop screen- and energy-save
defaults -currentHost write com.apple.screensaver idleTime 0
sudo pmset sleep 0 || true
sudo pmset displaysleep 0 || true
sudo pmset disksleep 0 || true

# kill feedback assistant
pkill Feedback || true

sudo rm -rf /Library/Caches/* 2>&1 > /dev/null
rm -rf ~/Library/Caches/* 2>&1 > /dev/null

if (! sudo diskutil secureErase freespace 0 /Volumes/Macintosh\ HD)
then
    cat /dev/zero > wipeout; rm wipeout
fi

exit 0
