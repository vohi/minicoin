#!/bin/bash
. /opt/minicoin/util/parse-opts.sh "$@"

cd $HOME

conan_path=$(find $PWD -name conan)
conan_path=$(dirname "$conan_path")

if [[ -z $conan_path ]]
then
    >&2 echo "Can't locate conan"
    exit 1
fi

echo "Using conan from $conan_path"
export PATH=$conan_path:$PATH

[[ ! -z $FLAG_profiles ]] && echo "Available profiles:"
cd $conan_path/profiles
for profile in $(find $PWD -name "qt-*-${PARAM_profile}*")
do
    [[ ! -z $FLAG_profiles ]] && echo $(basename $profile)
    conan_profile=$profile
done
[[ ! -z $FLAG_profiles ]] && exit 0

if [[ -z $conan_profile ]]
then
    >&2 echo "Can't locate conan profile"
    exit 2
fi

echo "Using conan profile $conan_profile"
for line in $(grep = $conan_profile)
do
    key=$(echo $line | awk -F "=" {'print $1'})
    value=$(echo $line | awk -F "=" {'print $2'})
    [[ $key == qt6 ]] && QT_VERSION=$value
    [[ $key == QT_PATH ]] && QT_PATH=$value
done

if [[ -z $QT_VERSION ]]
then
    >&2 echo "Can't read Qt version from $conan_profile"
    exit 3
fi

echo Using Qt version $QT_VERSION at $QT_PATH

cd $JOBDIR
if [[ ! -f conanfile.py ]]
then
    >&2 echo "No conanfile.py file found in $JOBDIR"
    exit 4
fi

module_name=$(basename $JOBDIR)
echo "Exporting module $module_name"
conan export . $module_name/$QT_VERSION@qt/testing

cd $HOME
[[ -d conan_test ]] && rm -rf conan_test
mkdir conan_test
cd conan_test

echo "Installing module $module_name with profile $conan_profile"
conan install $module_name/$QT_VERSION@qt/testing --build=missing --profile=$conan_profile
