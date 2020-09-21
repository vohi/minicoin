#!/usr/bin/env bash

. /minicoin/util/parse-opts.sh "$@"

# set defaults
build=
configure=
generate_toollink=()
target=

if [[ $JOBDIR == "" ]]; then
  echo "Error: path to host clone of Qt module is required!"
  exit 1
fi

sources=$JOBDIR
module=$(basename -s .pro $(ls $sources/*.pro))
if [[ $(echo $module | wc -w) != 1 ]]; then
  echo "$sources needs to have exactly one .pro file!"
  exit 1
fi

[[ ! -z $PARAM_target ]] && target=$PARAM_target
[[ ! -z $PARAM_build ]] && build=-$PARAM_build
if [[ $PARAM_configure != "" ]]; then
  configure=$PARAM_configure
  if [[ -f "$HOME/$configure.opt" ]]; then
    config_opt=$HOME/$configure.opt
  fi
else
  config_opt=$HOME/config.opt
fi

if [[ ! -z $FLAG_clean ]]
then
  echo "Cleaning existing build in '$module-build$build'"
  rm -rf $module-build$build
fi

mkdir $module-build$build 2> /dev/null
cd $module-build$build

echo "Building '$module' from '$sources'"

if [ -f CMakeCache.txt ] && [ -z $configure ]
then
  echo "'$module' already configured with cmake"
elif [ -f Makefile ] && [ -z $configure ]
then
  echo "'$module' already configured with qmake"
elif [[ -f "$sources/configure" ]]
then
  generate_toollink=( "qmake" )
  configure="-confirm-license -developer-build -opensource -nomake examples $configure"
  if [ -f $sources/CMakeLists.txt ]
  then
    generate_toollink=( $generate_toollink "qt-cmake" )
    configure="$configure -cmake -cmake-generator Ninja"
  fi
  echo "Configuring '$module' with options '$configure'"

  $sources/configure $configure
elif [ -f $sources/CMakeLists.txt ]
then
  echo "Generating cmake build for '$module'"
  ~/qt-cmake $sources -GNinja
  error=$?
else
  echo "Generating qmake build for '$module'"
  ~/qmake $sources
  error=$?
fi

for tool in "${generate_toollink[@]}"
do
  echo "Creating link to $tool..."
  linkname="-latest"
  if [[ $build != "" ]]
  then
    linkname=$build
  fi
  toolname=$tool$linkname
  rm ~/$toolname 2> /dev/null > /dev/null
  echo "$PWD/bin/$tool \"\$@\"" > ~/$toolname
  chmod +x ~/$toolname
  rm ~/$tool 2> /dev/null > /dev/null
  ln -s -f ~/$toolname ~/$tool
  sudo ln -s -f  ~/$toolname /usr/local/bin/$tool
done

if [ -f build.ninja ]
then
  if [ -z $target ]
  then
    target="src/all"
    [ $module == "qtbase" ] && target="$target qmake"
  fi
  echo "Building '$target' using ninja!"
  ninja $target
  error=$?
elif [ -f Makefile ]
then
  [ -z $target ] && target="sub-src"
  echo "Building '$target' using make!"
  make $target -j$(nproc)
  error=$?
else
  >&2 echo "No build system generated, aborting"
fi

exit $error
