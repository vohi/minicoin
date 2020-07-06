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

cd $project
if [ -f "$source/CMakeLists.txt" ]
then
  qt-cmake $source
else
  qmake $sources
fi

export DISPLAY=:0.0
if [ -f build.ninja ]
then
  ninja $PARAM_target
elif [ -f Makefile ]
  make $PARAM_target -j$(nproc)
else
  echo "Error generating build system"
  exit 1
fi
