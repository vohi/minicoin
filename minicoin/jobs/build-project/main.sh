#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"

sources=${POSITIONAL[0]}

if [[ $sources == "" ]]; then
  echo "No project specified"
  exit 1
fi

echo "Building project in '$sources'"

project=$(basename $sources)
mkdir $project > /dev/null 2>&1

export DISPLAY=:0.0
if [[ -f "$HOME/make" ]]; then
  $HOME/make $sources $project $PARAM_make
else
  cd $project
  $HOME/qmake $sources
  make $PARAM_make
fi