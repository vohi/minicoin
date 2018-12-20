#!/usr/bin/env bash
git clone git://code.qt.io/qt/qt5.git
cd qt5
git pull

if [[ $1 != "" ]]; then
  git checkout $1
fi

./init-repository -f --module-subset=default,-qtwebkit,-qtwebkit-examples,-qtwebengine
mkdir ../qt5-build
cd ../qt5-build
../qt5/configure -confirm-license -developer-build -opensource -nomake examples -nomake tests
make -j4 module-qtbase
make -j4 module-qttools
