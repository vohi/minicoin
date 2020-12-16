#!/bin/bash
cd $(dirname "$0")

rm -rf coin

if [[ ! -z $COIN_ROOT ]]
then
    cp -r $COIN_ROOT coin
else
    echo "COIN_ROOT not set, cloning from upstream"
    git clone --single-branch --branch dev --depth 1 git://code.qt.io/qt/qt5.git

    mv qt5/coin coin
    rm -rf qt5
fi
