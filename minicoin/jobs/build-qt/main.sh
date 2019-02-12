#!/usr/bin/env bash
branch=dev
modules=essential
if [[ $1 != "" ]]; then
  branch=$1
fi
if [[ $2 != "" ]]; then
  modules=$2
fi

echo "Building Qt branch $branch"
git clone git://code.qt.io/qt/qt5.git
cd qt5
git checkout $1

./init-repository --force --module-subset=$modules
mkdir ../qt5-build
cd ../qt5-build
../qt5/configure -confirm-license -developer-build -opensource -nomake examples -nomake tests
make -j4 module-qtbase
