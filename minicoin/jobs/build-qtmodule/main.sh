#!/usr/bin/env bash

. /minicoin/util/parse-opts.sh "$@"

# set defaults
build=
generate_qmake=false

if [[ ${POSITIONAL[0]} == "" ]]; then
  echo "Error: path to host clone of Qt module is required!"
  exit 1
fi

sources=${POSITIONAL[0]}
module=$(basename -s .pro $(ls $sources/*.pro))
if [[ $(echo $module | wc -w) != 1 ]]; then
  echo "$sources needs to have exactly one .pro file!"
  exit 1
fi

[[ ! -z $PARAM_build ]] && build=-$PARAM_build

qmake_name="qmake$build"
mkdir $module-build$build
cd $module-build$build

echo "Building $module from $sources"

if [[ $module == "qtbase" ]]; then
  $sources/configure -confirm-license -developer-build -opensource -nomake examples -nomake tests $PARAM_configure
  generate_qmake=true
else
  ~/$qmake_name $sources
fi

make -j4

if [[ $generate_qmake == "true" ]]; then
  echo "$PWD/bin/qmake \$@" > ~/$qmake_name
  chmod +x ~/$qmake_name
fi
