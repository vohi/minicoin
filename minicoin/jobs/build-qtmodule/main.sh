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

mkdir $module-build$build 2>&1 > /dev/null
cd $module-build$build

echo "Building $module from $sources"

built=0
if [ -f build.ninja ]
then
  ninja qmake src/all
  built=1
elif [ -f Makefile ]
then
  make sub-src -j$(nproc)
  built=1
elif [[ $module == "qtbase" ]]
then
  if [[ -f $config_opt ]]
  then
    cp $config_opt ./config.opt
    configure="-redo"
    echo "Using configure options from $config_opt:"
    cat $config_opt
  else
    if [ -f $sources/CMakeLists.txt ]
    then
      configure="$configure -cmake"
    fi
    configure="-confirm-license -developer-build -opensource -nomake examples -nomake tests -pcre system -xcb $configure"
  fi
  echo "Configuring with options '$configure'"

  $sources/configure $configure
  generate_qmake=true
else
  ~/qmake $sources
fi

if [ $built -eq 0 ]
then
  if [ -f build.ninja ]
  then
    ninja qmake src/all
  else
    make sub-src -j$(nproc)
  fi
fi

if [[ $generate_qmake == "true" ]]; then
  qmake_name="qmake-latest"

  if [[ $build != "" ]]; then
    qmake_name=qmake$build
  fi
  rm ~/$qmake_name > /dev/null 2> /dev/null
  echo "$PWD/bin/qmake \"\$@\"" > ~/$qmake_name
  chmod +x ~/$qmake_name
  rm ~/qmake > /dev/null 2> /dev/null
  ln -s -f ~/$qmake_name ~/qmake
fi
