#!/usr/bin/env bash
echo "Building Qt branch $1"
git clone git://code.qt.io/qt/qt5.git
cd qt5
if [[ $1 != "" ]]; then
  git checkout $1
fi
./init-repository --force --module-subset=qtbase

if [[ $2 != "" ]]; then
  cd qtbase
  $(git remote remove local)
  $(git remote add local file://$2/qtbase)

  git fetch remote
  if [[ $3 != "" ]]; then
    echo "Checkout out qtbase branch '$3' from local clone"
    git checkout local/$3
  fi
  cd ..
fi

mkdir ../qt5-build
cd ../qt5-build
../qt5/configure -confirm-license -developer-build -opensource -nomake examples -nomake tests
make -j4 module-qtbase
