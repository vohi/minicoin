#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"

if [ -z $JOBDIR ]
then
  >&2 echo "Error: path to host clone of Qt is required!"
  exit 1
fi

# use highest installed version of gcc or clang, unless compilers are specified
function search_highest
{
  [ -z $1 ] && return
  local search_version=8
  local highest_found=
  while [[ -f "${1}-${search_version}" ]]
  do
    highest_found=$search_version
    search_version=$(( $search_version + 1 ))
  done
  [ -z ${highest_found} ] && echo "$1" || echo "${1}-${highest_found}"
}

export CC=${PARAM_cc:-$(search_highest "$(which gcc || which clang)")}
export CXX=${PARAM_cxx:-$(search_highest "$(which g++ || which clang++)")}

# create a build tool wrapper script in ~
function link_tool
{
  toolname="$1"
  binpath="$PWD/qtbase/bin"
  [ -f "${binpath}/${toolname}" ] || binpath="$PWD/bin"
  if [ -f "${binpath}/${toolname}" ]
  then
    echo "${binpath}/${toolname} \"\$@\"" > "$HOME/${toolname}"
    chmod +x "$HOME/${toolname}"
  fi
}

projectname="$(basename $JOBDIR)"

# set defaults
[ -z $PARAM_build ] && PARAM_build="${projectname}-build"
build_dir=$PARAM_build
target=$PARAM_target

error=0

if [ ! -z $FLAG_clean ]
then
  echo "Cleaning existing build in '$build_dir'"
  rm -rf $build_dir
fi

[ -d $build_dir ] || mkdir -p $build_dir &> /dev/null
cd $build_dir
echo "Building '$projectname' from '$JOBDIR' into '$build_dir'"

if [ -f build.ninja ]
then
  echo "Already configured with cmake - run with --clean to reconfigure"
elif [ -f Makefile ]
then
  echo "Already configured with qmake - run with --clean to reconfigure"
elif [ -f $JOBDIR/configure ]
then
  default_configure="-developer-build -confirm-license -opensource -nomake examples"
  [[ $(which ccache) ]] && default_configure="$default_configure -ccache -no-pch"
  configure=${PARAM_configure:-$default_configure}
  # not setting CMAKE_C(XX)_COMPILER, using CC and CXX environment instead
  [[ $configure == -D* ]] && configure="-- $configure"
  echo "Configuring '$JOBDIR' with 'configure $configure'"
  echo "Pass --configure \"configure options\" to override"
  $JOBDIR/configure $configure
elif [ -f $JOBDIR/CMakeLists.txt ]
then
  configure=${PARAM_configure:-"-GNinja"}
  [[ $configure == -D* ]] && configure="-- $configure"
  echo "Configuring '$JOBDIR' with 'qt-cmake ${configure}'"
  if [ ! -f ~/qt-cmake ]
  then
    >&2 echo "qt-cmake wrapper not found in '$HOME', build qtbase first!"
  else
    ~/qt-cmake "${configure}" $JOBDIR
  fi
elif [ -f $JOBDIR/$projectname.pro ]
then
  configure=${PARAM_configure:-"-GNinja"}
  echo "Configuring '$JOBDIR' with 'qmake ${configure}'"
  if [ ! -f ~/qmake ]
  then
    >&2 echo "qmake wrapper not found in '$HOME', build qtbase first!"
  else
    ~/qmake "${configure}" $JOBDIR
  fi
else
  >&2 echo "No CMake or qmake build system found"
  false
fi
error=$?


if [[ -f build.ninja ]]
then
  maketool=ninja
elif [[ -f Makefile ]]
then
  maketool="make -j$(nsproc)"
else
  >&2 echo "No build system generated, aborting"
  exit 1
fi

echo "Building '$JOBDIR' using '$maketool $target'"
$maketool $target
error=$?
if [[ "$PARAM_configure" == *"prefix"* ]]
then
  if [[ $error -eq 0 ]]
  then
    echo "Prefix build detected, installing"
    $maketool install
  else
    >&2 echo "Build failed, not installing"
  fi
fi

if [[ ! "$PARAM_configure" == *"xplatform"* ]]
then
  link_tool qmake
  link_tool qt-cmake
fi

exit $error
