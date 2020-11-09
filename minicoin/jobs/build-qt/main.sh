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
  [ -z highest_found ] || echo ${1}-${highest_found}
}

export CC=${PARAM_cc:-$(search_highest "$(which gcc || which clang)")}
export CXX=${PARAM_cxx:-$(search_highest "$(which g++ || which clang++)")}

# create a build tool wrapper script in ~
function link_tool
{
  toolname="$1"
  if [ -f "$PWD/qtbase/bin/${toolname}" ]
  then
    echo "$PWD/qtbase/bin/${toolname} \"\$@\"" > "$HOME/${toolname}"
    chmod +x "$HOME/${toolname}"
  fi
}

# set defaults
build_dir=${PARAM_build:-"qt-build"}
target=$PARAM_target

error=0

if [ ! -z $FLAG_clean ]
then
  echo "Cleaning existing build in '$build_dir'"
  rm -rf $build_dir
fi

[ -d $build_dir ] || mkdir -p $build_dir &> /dev/null
cd $build_dir
echo "Building '$JOBDIR' into '$build_dir'"

if [ -f CMakeCache.txt ]
then
  echo "Already configured with cmake - run with --clean to reconfigure"
elif [ -f Makefile ]
then
  echo "Already configured with qmake - run with --clean to reconfigure"
elif [ -f $JOBDIR/CMakeLists.txt ] && [ -z $FLAG_qmake ]
then
  configure=${PARAM_configure:-"-GNinja -DFEATURE_developer_build=ON -DBUILD_EXAMPLES=OFF"}
  echo "Configuring with cmake: $configure"
  echo "Pass --configure \"configure options\" to override"
  cmake $configure $JOBDIR
elif [ -f $JOBDIR/configure ]
then
  configure=${PARAM_configure:-"-developer-build -confirm-license -opensource -nomake examples"}
  echo "Configuring with qmake: $configure"
  echo "Pass --configure \"configure options\" to override"
  $JOBDIR/configure $configure
else
  >&2 echo "No CMake or qmake build system found"
  false
fi
error=$?

if [[ -f build.ninja ]]
then
  echo "Building '$JOBDIR' using 'ninja $target'"
  ninja $target
  error=$?
elif [[ -f Makefile ]]
then
  echo "Building '$JOBDIR' using 'make $target -j$(nproc)'"
  make $target -j$(nproc)
  error=$?
else
  >&2 echo "No build system generated, aborting"
fi

link_tool qmake
link_tool qt-cmake

exit $error
