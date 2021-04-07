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
  local binary="$1"
  local have_version=8
  if which realpath &> /dev/null
  then
    [ -L $binary ] && binary="$(realpath $binary)"
  else
    [ -L $binary ] && binary="$(readlink $binary)"
  fi
  regexp='(.*)-([0-9]+$)'
  [[ $binary =~ $regexp ]] && binary="${BASH_REMATCH[1]}"; have_version="${BASH_REMATCH[2]}"

  local highest_found=$have_version
  attempts=1
  while true
  do
    local search_version=$(( $have_version + $attempts ))
    [[ -f "${binary}-${search_version}" ]] && highest_found=$(( $have_version + $attempts ))
    search_version=$(( $have_version + $attempts ))
    attempts=$(( $attempts + 1 ))
    [[ $attempts -gt 10 ]] && break
  done
  [ -z ${highest_found} ] && echo "$binary" || echo "${binary}-${highest_found}"
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

if [ ! -z $FLAG_reconfigure ]
then
  rm build.ninja CMakeCache.txt Makefile .qmake.cache 2>&1 > /dev/null
  [ -z $PARAM_configure ] && PARAM_configure="-redo"
fi

if [ -f build.ninja ]
then
  echo "Already configured with cmake - run with --clean to reconfigure"
elif [ -f Makefile ]
then
  echo "Already configured with qmake - run with --clean to reconfigure"
elif [ -f $JOBDIR/configure ]
then
  default_configure="-developer-build -confirm-license -opensource -nomake examples"
  [[ -x $(command -v ccache) ]] && default_configure="$default_configure -ccache -no-pch"
  configure=${PARAM_configure:-$default_configure}
  # not setting CMAKE_C(XX)_COMPILER, using CC and CXX environment instead
  [[ $configure == -D* ]] && configure="-- $configure"
  echo "Configuring '$JOBDIR' with 'configure $configure'"
  echo "Pass --configure \"configure options\" to override"
  $JOBDIR/configure $configure
elif [ -f $JOBDIR/CMakeLists.txt ]
then
  [ $(command -v ninja) ] && generator="-GNinja"
  configure=${PARAM_configure:-$generator}
  echo "Configuring '$JOBDIR' with 'qt-cmake ${configure}'"
  if [ ! -f ~/qt-cmake ]
  then
    >&2 echo "qt-cmake wrapper not found in '$HOME', using plain cmake!"
    cmake "${configure}" $JOBDIR
  else
    ~/qt-cmake "${configure}" $JOBDIR
  fi
elif [ -f $JOBDIR/$projectname.pro ]
then
  echo "Configuring '$JOBDIR' with 'qmake ${PARAM_configure}'"
  if [ ! -f ~/qmake ]
  then
    >&2 echo "qmake wrapper not found in '$HOME', build qtbase first!"
  else
    ~/qmake "${PARAM_configure}" $JOBDIR
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
  cpus=$(nproc 2> /dev/null || sysctl -n hw.ncpu)
  maketool="make -j${cpus}"
else
  >&2 echo "No build system generated, aborting"
  exit 1
fi

[[ -z $PARAM_testargs ]] || export TESTARGS=$PARAM_testargs

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
