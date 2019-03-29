#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh

# set defaults
branch=
modules=essential
repo=git://code.qt.io/qt/qt5.git
sources=../qt5 # location of sources relative to build dir
configure=
generate_qmake=false
error=0

if [[ $PARAM_branch != "" ]]; then
  # branch implies cloning from upstream, a local clone can't be init'ed from
  branch=$PARAM_branch
elif [[ ${POSITIONAL[0]} != "" ]]; then
  origin=${POSITIONAL[0]}
  if [[ -f $origin/qt.pro ]]; then
    repo=
    sources=$origin
  else
    echo "$origin is not a Qt5 super repo - ignoring"
    exit 1
  fi
fi
if [[ $PARAM_modules != "" ]]; then
  modules=$PARAM_modules
fi
if [[ $PARAM_configure != "" ]]; then
  configure=$PARAM_configure
fi

if [[ $repo != "" ]]; then
  echo "Cloning from '$repo'"
  if [[ $branch != "" ]]; then
    echo "Checking out branch '$branch'"
    branch="--branch $branch"
  fi
  git clone $branch $repo
  error=$?
  cd qt5

  echo "Initializing repository for modules '$modules'"
  ./init-repository --force --mirror=$repo/ --module-subset=$modules
  error=$? || error

  cd ..
fi

if [[ ! $error -eq 0 ]]; then
  echo "Error cloning and initializing repo!"
  exit $error
fi

if [[ $modules == "essential" ]]; then
  modules=
fi

mkdir qt5-build
cd qt5-build

echo "Configuring with options '$configure'"
$sources/configure -confirm-license -developer-build -opensource -nomake examples -nomake tests $configure

if [[ $modules != "" ]]; then
  module_array=()
  IFS=',' read -r -a module_array <<< "$modules"
  for module in "${module_array[@]}"; do
    echo "Building $module"
    make -j4 module-$module
    if [[ $module == "qtbase" ]]; then
      generate_qmake=true
    fi
  done
else
  make -j4
  generate_qmake=true
fi

if [[ $generate_qmake == "true" ]]; then
  echo "$PWD/qtbase/bin/qmake \$@" > ~/qmake
  chmod +x ~/qmake
fi
