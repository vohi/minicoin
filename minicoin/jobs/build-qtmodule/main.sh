#!/usr/bin/env bash

. /minicoin/util/parse-opts.sh "$@"

# set defaults
build=
configure=
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
if [[ $PARAM_configure != "" ]]; then
  configure=$PARAM_configure
  if [[ -f "$HOME/$configure.opt" ]]; then
    config_opt=$HOME/$configure.opt
  fi
else
  config_opt=$HOME/config.opt
fi

qmake_name="qmake$build"
mkdir $module-build$build
cd $module-build$build

echo "Building $module from $sources"

if [[ $module == "qtbase" ]]; then
  if [[ -f $config_opt ]]; then
    cp $config_opt ./config.opt
    configure="-redo"
    echo "Using configure options from $config_opt:"
    cat $config_opt
  else
    configure="-confirm-license -developer-build -opensource -nomake examples -nomake tests $configure"
  fi
  echo "Configuring with options '$configure'"

  $sources/configure $configure
  generate_qmake=true
else
  ~/$qmake_name $sources
fi

make -j4

if [[ $generate_qmake == "true" ]]; then
  echo "$PWD/bin/qmake \$@" > ~/$qmake_name
  chmod +x ~/$qmake_name
fi
