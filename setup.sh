#!/bin/bash

echo "Checking vagrant installation..."
if [ ! $(which vagrant 2>&1 /dev/null) ]
then
    echo "- vagrant not found, please install before using minicoin"
elif [ ! "vagrant --version" ]
then
    echo "- vagrant installation broken, please repair before using minicoin"
fi

if [ -d "/usr/local/bin" ]
then
    echo "Linking minicoin to /usr/local/bin"
    ln -fs $PWD/minicoin/minicoin /usr/local/bin/minicoin
fi

