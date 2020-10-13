#!/bin/bash

printf "Checking vagrant installation..."
if [ ! $(which vagrant 2>&1 /dev/null) ]
then
    echo " - not found, please install before using minicoin"
elif [ ! "vagrant --version" ]
then
    echo " - vagrant installation broken, please repair before using minicoin"
else
    echo " - ok!"
fi

printf "Checking for the winrm ruby gem..."
if [[ ! $(gem list winrm2 | grep winrm) ]]
then
    echo " - not found!"
    echo
    echo "  run"
    echo
    echo "  $ sudo gem install winrm"
    echo
    echo "  to be able to use Windows VMs!"
    echo
else
    echo " - ok!"
fi

if [ -d "/usr/local/bin" ]
then
    echo "Linking minicoin to /usr/local/bin"
    ln -fs $PWD/minicoin/minicoin /usr/local/bin/minicoin
fi
