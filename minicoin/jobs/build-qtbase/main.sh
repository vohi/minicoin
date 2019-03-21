#!/usr/bin/env bash
if [[ "$1" == "" ]]; then
  echo "Error: path to host clone of qtbase is required!"
  exit 1
fi

echo "Building Qt Base from $1"

$(git clone --origin local file://$1/qtbase qtbase)
cd qtbase

echo "Fetching $1"
git fetch local

BRANCH=dev
if [[ $2 != "" ]]; then
  BRANCH=$2
fi

echo "Checking out $BRANCH"
git checkout local/$BRANCH

mkdir ../qtbase-build
cd ../qtbase-build
../qtbase/configure -confirm-license -developer-build -opensource -nomake examples -nomake tests

make -j4
error=$?

if [[ $error == 0 ]]; then
  echo "$PWD/bin/qmake \$@" > ~/qmake
  chmod +x ~/qmake
else
  rm ~/qmake
fi
