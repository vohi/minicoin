#!/bin/bash
set -euo pipefail

if (! grep "added by packer" ~/.zshrc)
then
    echo 'export PATH="/usr/local/bin:$PATH" # added by packer' >> ~/.zshrc
fi

echo "Running update"
/usr/local/bin/brew update
echo "Running cleanup"
/usr/local/bin/brew cleanup --prune=all
echo "Running doctor"
/usr/local/bin/brew doctor || true
echo "Running autoremove"
/usr/local/bin/brew autoremove
echo "Running upgrade"
/usr/local/bin/brew upgrade
echo "Running cleanup"
/usr/local/bin/brew cleanup --prune=all
echo "Running autoremove"
/usr/local/bin/brew autoremove

exit 0
