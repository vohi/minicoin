#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"

if [ -z $JOBDIR ]
then
  echo "Error: path to host clone of Qt is required!"
  exit 1
fi

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
echo "Building $JOBDIR into $build_dir"

if [ -f CMakeCache.txt ]
then
  echo "Already configured with cmake - run with --clean to reconfigure"
elif [ -f Makefile ]
then
  echo "Already configured with qmake - run with --clean to reconfigure"
elif [ -f $JOBDIR/CMakeLists.txt ]
then
  configure=${PARAM_configure:-"-GNinja -DFEATURE_developer_build=ON -DBUILD_EXAMPLES=OFF"}
  echo "Configuring with cmake: $configure"
  echo "Pass --configure \"configure options\" to override"
  cmake $configure $JOBDIR
else
  configure=${PARAM_configure:-"-developer-build -confirm-license -opensource -nomake examples"}
  echo "Configuring with qmake: $configure"
  echo "Pass --configure \"configure options\" to override"
  $JOBDIR/configure $configure
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

exit $error
