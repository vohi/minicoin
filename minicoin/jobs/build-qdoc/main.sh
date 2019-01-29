#!/usr/bin/env bash
git clone git://code.qt.io/qt/qt5.git
cd qt5

if [[ $1 != "" ]]; then
  git checkout $1
fi

git pull
./init-repository -f --module-subset=default,-qtwebkit,-qtwebkit-examples,-qtwebengine

if [[ $2 != "" ]]; then
  echo "Fetching qttools from local '$2'"
  cd qttools
  $(git remote remove local)
  $(git remote add local file://$2/qttools)
  git fetch local

  if [[ $3 != "" ]]; then
    echo "Checkout out qttools branch '$3' from local remote"
    git checkout local/$3
  fi
  cd ..
fi

mkdir ../qt5-build
cd ../qt5-build
../qt5/configure -confirm-license -developer-build -opensource -nomake examples -nomake tests -recheck-all
make -j4 module-qtbase
make -j4 module-qttools