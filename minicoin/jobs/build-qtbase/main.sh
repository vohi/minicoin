#!/usr/bin/env bash
echo "Building Qt branch $1"
git clone git://code.qt.io/qt/qtbase.git
cd qtbase

BRANCH=dev

if [[ $1 != "" ]]; then
  BRANCH=$1
fi

if [[ $2 != "" ]]; then
  echo "Fetching $2/qtbase"
  $(git remote remove local)
  $(git remote add local file://$2/qtbase)

  git fetch local
  BRANCH=local/$1
fi

echo "Checking out $BRANCH"
git checkout $BRANCH

mkdir ../qtbase-build
cd ../qtbase-build
../qtbase/configure -confirm-license -developer-build -opensource -nomake examples -nomake tests

make -j4