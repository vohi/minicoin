#!/usr/bin/env bash
if [[ $2 != "" ]]; then
  echo "Fetching module $1 from local $2"
  cd ~/qt5/$1
  $(git remote add local file://$2/$1)
  git fetch local

  if [[ $3 != "" ]]; then
    echo "Checking out branch $3"
    git checkout local/$3
  fi
fi

echo "Building HTML docs for $1 into '~/qt5-build/qtbase/doc/qtdoc'"
cd ~/qt5-build
if [[ $1 != "" ]]; then
  cd $1
fi

make html_docs
