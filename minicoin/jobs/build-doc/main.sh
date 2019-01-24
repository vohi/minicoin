#!/usr/bin/env bash
if [[ $2 != "" ]]; then
  echo "Fetching module $1 from local $2"
  cd ~/qt5/$1
  $(git remote add local file://$2)
  git fetch local

  if [[ $3 != "" ]]; then
    echo "Checking out branch $3"
    git checkout local/$3
  fi
fi

outputdir=~/qt5-build/qtbase/doc

echo "Building HTML docs for '$1' into '$outputdir'"
cd ~/qt5-build
if [[ $1 != "" ]]; then
  cd $1
fi

make html_docs

cd $outputdir
rm diff.txt
date > now.log # make sure there's a change
git init -q
git add .

commit="Build of '$1'"
if [[ $2 != "" ]]; then
  commit+=" from '$2'"
  if [[ $3 != "" ]]; then
    commit+=" branch '$3'"
  fi
fi

git commit -q -m "$commit"
git show > diff.txt

if [[ $2 != "" ]]; then
  cd ~/qt5/$1
  git remote remove local
fi

