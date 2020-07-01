#!/usr/bin/env bash

. /minicoin/util/parse-opts.sh "$@"

# set defaults
build=
configure=
generate_toollink=()

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

mkdir $module-build$build 2> /dev/null
cd $module-build$build

echo "Building '$module' from '$sources'"

if [ -f build.ninja ]
then
  echo "'$module' already configured with cmake"
elif [ -f Makefile ]
then
  echo "'$module' already configured with qmake"
elif [[ $module == "qtbase" ]]
then
  generate_toollink=( "qmake" )
  if [[ -f $config_opt ]]
  then
    cp $config_opt ./config.opt
    configure="-redo"
    echo "Using configure options from $config_opt:"
    cat $config_opt
  else
    targets="sub-src"
    if [ -f $sources/CMakeLists.txt ]
    then
      targets="qmake src/all"
      configure="$configure -cmake"
      generate_toollink=( $generate_toollink "qt-cmake" )
    fi
    configure="-confirm-license -developer-build -opensource -nomake examples -nomake tests -pcre system -xcb $configure"
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
  ninja $targets
  error=$?
elif [ -f Makefile ]
then
  make $targets -j$(nproc)
  error=$?
else
  2> echo "No build system generated, aborting"
fi

exit $error