#!/usr/bin/env bash
. /minicoin/util/parse-opts.sh "$@"

sources=${POSITIONAL[0]}
build_dir=~/qt5-build
modules=

if [[ $PARAM_build != "" ]]; then
  build_dir=$PARAM_build
fi
if [[ $PARAM_modules != "" ]]; then
  modules=$PARAM_modules
fi

outputdir=$build_dir/qtbase/doc

echo "Building HTML docs for '$sources' into '$outputdir'"
cd $build_dir

if [[ $modules == "" ]]; then
  make html_docs
else
  module_array=()
  IFS=',' read -r -a module_array <<< "$modules"
  for module in "${module_array[@]}"; do
    echo "Building $module"
    cd $module
    make html_docs
    cd ..
  done
fi

cd $outputdir
rm diff.txt
date > now.log # make sure there's a change
git init -q
git add .

git commit -q -m "Build of '$sources'"
git show > diff.txt