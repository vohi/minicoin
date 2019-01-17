#!/usr/bin/env bash
echo "Building Qt branch $1"
git clone git://code.qt.io/qt/qt5.git
cd qt5
if [[ $1 != "" ]]; then
  git checkout $1
fi

./init-repository --module-subset=default,-qtwebkit,-qtwebkit-examples,-qtwebengine,-qt3d
mkdir ../qt5-build
cd ../qt5-build
../qt5/configure -confirm-license -developer-build -opensource -nomake examples -nomake tests
make -j4 module-qtbase
