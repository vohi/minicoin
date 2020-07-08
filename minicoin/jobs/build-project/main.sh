#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"

sources=${POSITIONAL[0]}

if [[ $sources == "" ]]; then
  echo "No project specified"
  exit 1
fi

project=$(basename $sources)
mkdir $project > /dev/null 2>&1
cd $project

printf "Building project in '$sources' into '$PWD' "

if [ -f "$sources/CMakeLists.txt" ]
then
  printf "using cmake\n"
  qt-cmake $sources
else
  pringf "using qmake\n"
  qmake $sources
fi

export DISPLAY=:0.0

if [ -f build.ninja ]
then
  ninja $PARAM_target
elif [ -f Makefile ]
then
  make $PARAM_target -j$(nproc)
else
  echo "Error generating build system"
  exit 1
fi
